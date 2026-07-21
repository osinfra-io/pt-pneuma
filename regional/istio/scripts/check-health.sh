#!/bin/bash
set -euo pipefail

# Check Istio health across all clusters in an environment.
#
# Clusters are discovered automatically across all teams by querying every
# GCP project labeled labels.repository=pt-corpus for the environment. Any
# project that has GKE clusters is included. Credentials are written to a
# temporary kubeconfig file and cleaned up on exit — nothing is written to
# ~/.kube/config.
#
# Usage: ./check-health.sh <env>
#   env: sb (sandbox), nonprod (non-production), prod (production)

# Colors and formatting.

RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
GRAY='\033[0;90m'
BOLD='\033[1m'
RESET='\033[0m'

# Disable colors if not a terminal.

if [[ ! -t 1 ]]; then
  RED="" YELLOW="" BLUE="" GREEN="" CYAN="" GRAY="" BOLD="" RESET=""
fi

# Wrap text to terminal width with indentation.

wrap_text() {
  local indent="${1}"
  local text="${2}"
  local width=${COLUMNS:-80}
  local effective_width=$((width - ${#indent}))

  # Ensure minimum width.
  [[ ${effective_width} -lt 40 ]] && effective_width=40

  echo "${text}" | fold -s -w "${effective_width}" | while IFS= read -r line; do
    echo "${indent}${line}"
  done
}

if [[ $# -lt 1 ]] || [[ $# -gt 2 ]]; then
  echo "Usage: $0 [-v] <env>"
  echo "  -v:  verbose — show info messages"
  echo "  env: sb, nonprod, or prod"
  exit 1
fi

VERBOSE=false
if [[ "${1}" == "-v" ]]; then
  VERBOSE=true
  shift
fi

ENV="${1}"

case "${ENV}" in
  sb | nonprod | prod) ;;
  *)
    echo "Error: env must be one of: sb, nonprod, prod"
    exit 1
    ;;
esac

# Namespace prefixes to skip when running istioctl analyze.
# These are system namespaces that don't participate in the mesh.

SKIP_NAMESPACE_PREFIXES=(
  "gke-"
  "gmp-"
  "kube-"
)

# Use a temporary kubeconfig — never writes to ~/.kube/config.

KUBECONFIG_FILE="$(mktemp)"
ANALYZE_OUTPUT="$(mktemp)"
trap 'rm -f "${KUBECONFIG_FILE}" "${ANALYZE_OUTPUT}"' EXIT
export KUBECONFIG="${KUBECONFIG_FILE}"

# Discover all pt-corpus projects for this environment, then find which ones
# have GKE clusters.

declare -A CLUSTER_ZONES
declare -A CLUSTER_PROJECT
declare -a CLUSTER_NAMES=()

echo -e "${GRAY}Discovering clusters for env '${ENV}'...${RESET}"

mapfile -t PROJECTS < <(gcloud projects list \
  --filter="labels.repository=pt-corpus" \
  --format="value(projectId)" 2>/dev/null | grep "\-${ENV}$" || true)

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  echo -e "${RED}✗ No pt-corpus projects found for env '${ENV}'.${RESET}"
  exit 1
fi

for PROJECT in "${PROJECTS[@]}"; do
  mapfile -t CLUSTER_ROWS < <(gcloud container clusters list \
    --project="${PROJECT}" \
    --format="csv[no-heading](name,location)" 2>/dev/null || true)

  [[ ${#CLUSTER_ROWS[@]} -eq 0 ]] && continue

  for row in "${CLUSTER_ROWS[@]}"; do
    NAME="${row%%,*}"
    ZONE="${row##*,}"
    CLUSTER_ZONES["${NAME}"]="${ZONE}"
    CLUSTER_PROJECT["${NAME}"]="${PROJECT}"
    CLUSTER_NAMES+=("${NAME}")
  done
done

if [[ ${#CLUSTER_NAMES[@]} -eq 0 ]]; then
  echo -e "${RED}✗ No GKE clusters found for env '${ENV}'.${RESET}"
  exit 1
fi

# Sort cluster names for consistent output.

IFS=$'\n' CLUSTER_NAMES=($(sort <<<"${CLUSTER_NAMES[*]}")); unset IFS

echo -e "${GRAY}Found ${#CLUSTER_NAMES[@]} cluster(s): ${CLUSTER_NAMES[*]}${RESET}"
echo

# Fetch credentials for all clusters (suppress output).

for NAME in "${CLUSTER_NAMES[@]}"; do
  gcloud container clusters get-credentials "${NAME}" \
    --zone="${CLUSTER_ZONES[${NAME}]}" \
    --project="${CLUSTER_PROJECT[${NAME}]}" \
    --quiet 2>/dev/null
done

# Counters for summary.

declare -A ERROR_COUNT
declare -A WARNING_COUNT
declare -A INFO_COUNT
declare -A PROXY_SYNCED
declare -A REMOTE_SYNCED

# Run health checks on each cluster.

for NAME in "${CLUSTER_NAMES[@]}"; do
  PROJECT="${CLUSTER_PROJECT[${NAME}]}"
  CTX="gke_${PROJECT}_${CLUSTER_ZONES[${NAME}]}_${NAME}"

  echo -e "${BOLD}${CYAN}━━━ ${NAME} ━━━${RESET}"

  # Initialize counters.
  ERROR_COUNT["${NAME}"]=0
  WARNING_COUNT["${NAME}"]=0
  INFO_COUNT["${NAME}"]=0

  # Get all namespaces and filter out the skip list.
  mapfile -t NAMESPACES < <(kubectl get namespaces \
    --context="${CTX}" \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | sort)

  # Collect analyze output for all namespaces.
  > "${ANALYZE_OUTPUT}"

  for NS in "${NAMESPACES[@]}"; do
    skip=false
    for PREFIX in "${SKIP_NAMESPACE_PREFIXES[@]}"; do
      if [[ "${NS}" == "${PREFIX}"* ]]; then
        skip=true
        break
      fi
    done
    [[ "${skip}" == "true" ]] && continue

    timeout 60 istioctl analyze --context="${CTX}" -n "${NS}" 2>&1 | \
      grep -E "^(Error|Warning|Info) \[" >> "${ANALYZE_OUTPUT}" || true
  done

  # Parse and display issues by severity.

  # Errors first.
  mapfile -t ERRORS < <(grep "^Error " "${ANALYZE_OUTPUT}" | sort -u || true)
  if [[ ${#ERRORS[@]} -gt 0 ]] && [[ -n "${ERRORS[0]}" ]]; then
    ERROR_COUNT["${NAME}"]=${#ERRORS[@]}
    echo -e "\n${RED}🔴 Errors (${#ERRORS[@]})${RESET}"
    for line in "${ERRORS[@]}"; do
      # Extract code and resource.
      code=$(echo "${line}" | grep -oP '\[IST\d+\]' || echo "")
      resource=$(echo "${line}" | grep -oP '\([^)]+\)' | head -1 || echo "")
      msg=$(echo "${line}" | sed 's/^Error \[IST[0-9]*\] \[[^]]*\] ([^)]*) //')
      echo -e "  ${GRAY}${code}${RESET} ${resource}"
      wrap_text "    " "${msg}"
    done
  fi

  # Warnings.
  mapfile -t WARNINGS < <(grep "^Warning " "${ANALYZE_OUTPUT}" | sort -u || true)
  if [[ ${#WARNINGS[@]} -gt 0 ]] && [[ -n "${WARNINGS[0]}" ]]; then
    WARNING_COUNT["${NAME}"]=${#WARNINGS[@]}
    echo -e "\n${YELLOW}🟡 Warnings (${#WARNINGS[@]})${RESET}"
    for line in "${WARNINGS[@]}"; do
      code=$(echo "${line}" | grep -oP '\[IST\d+\]' || echo "")
      resource=$(echo "${line}" | grep -oP '\([^)]+\)' | head -1 || echo "")
      msg=$(echo "${line}" | sed 's/^Warning \[IST[0-9]*\] \[[^]]*\] ([^)]*) //')
      echo -e "  ${GRAY}${code}${RESET} ${resource}"
      wrap_text "    " "${msg}"
    done
  fi

  # Info (collapsed count only, unless verbose).
  mapfile -t INFOS < <(grep "^Info " "${ANALYZE_OUTPUT}" | sort -u || true)
  if [[ ${#INFOS[@]} -gt 0 ]] && [[ -n "${INFOS[0]}" ]]; then
    INFO_COUNT["${NAME}"]=${#INFOS[@]}
    if [[ "${VERBOSE}" == "true" ]]; then
      echo -e "\n${BLUE}🔵 Info (${#INFOS[@]})${RESET}"
      for line in "${INFOS[@]}"; do
        code=$(echo "${line}" | grep -oP '\[IST\d+\]' || echo "")
        resource=$(echo "${line}" | grep -oP '\([^)]+\)' | head -1 || echo "")
        msg=$(echo "${line}" | sed 's/^Info \[IST[0-9]*\] \[[^]]*\] ([^)]*) //')
        echo -e "  ${GRAY}${code}${RESET} ${resource}"
        wrap_text "    " "${msg}"
      done
    else
      echo -e "\n${BLUE}🔵 Info (${#INFOS[@]})${RESET} ${GRAY}— run with -v to show${RESET}"
    fi
  fi

  # If no issues, show clean status.
  if [[ ${ERROR_COUNT["${NAME}"]} -eq 0 ]] && \
     [[ ${WARNING_COUNT["${NAME}"]} -eq 0 ]] && \
     [[ ${INFO_COUNT["${NAME}"]} -eq 0 ]]; then
    echo -e "${GREEN}✓ No issues found${RESET}"
  fi

  # Proxy status — just show count.
  proxy_output=$(istioctl proxy-status --context="${CTX}" 2>&1 || true)
  synced_count=$(echo "${proxy_output}" | grep -c "CDS,LDS,EDS,RDS" || true)
  synced_count=${synced_count:-0}
  PROXY_SYNCED["${NAME}"]="${synced_count}"

  echo -e "\n${GREEN}✓ Proxies: ${synced_count} synced${RESET}"

  # Remote clusters — count unique cluster names (not per-istiod lines).
  remote_output=$(istioctl remote-clusters --context="${CTX}" 2>&1 || true)
  remote_total=$(echo "${remote_output}" | awk '/synced/ {print $1}' | sort -u | wc -l)
  remote_total=${remote_total:-0}
  REMOTE_SYNCED["${NAME}"]="${remote_total}"

  echo -e "${GREEN}✓ Remote clusters: ${remote_total} synced${RESET}"

  echo
done

# Summary.

echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo -e "${BOLD}Summary${RESET}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
echo

total_errors=0
total_warnings=0
total_infos=0

printf "%-30s %8s %8s %8s %10s %8s\n" "Cluster" "Errors" "Warnings" "Info" "Sidecars" "Peers"
printf "%-30s %8s %8s %8s %10s %8s\n" "-------" "------" "--------" "----" "--------" "-----"

for NAME in "${CLUSTER_NAMES[@]}"; do
  e=${ERROR_COUNT["${NAME}"]}
  w=${WARNING_COUNT["${NAME}"]}
  i=${INFO_COUNT["${NAME}"]}
  p=${PROXY_SYNCED["${NAME}"]}
  r=${REMOTE_SYNCED["${NAME}"]}

  total_errors=$((total_errors + e))
  total_warnings=$((total_warnings + w))
  total_infos=$((total_infos + i))

  # Color code based on status.
  if [[ ${e} -gt 0 ]]; then
    status_color="${RED}"
  elif [[ ${w} -gt 0 ]]; then
    status_color="${YELLOW}"
  else
    status_color="${GREEN}"
  fi

  printf "${status_color}%-30s %8d %8d %8d %10d %8d${RESET}\n" "${NAME}" "${e}" "${w}" "${i}" "${p}" "${r}"
done

echo
echo -e "${GRAY}Sidecars = Envoy proxies synced with Istiod | Peers = remote clusters in mesh${RESET}"

echo
if [[ ${total_errors} -gt 0 ]]; then
  echo -e "${RED}🔴 ${total_errors} error(s), ${total_warnings} warning(s), ${total_infos} info${RESET}"
  exit 1
elif [[ ${total_warnings} -gt 0 ]]; then
  echo -e "${YELLOW}🟡 ${total_warnings} warning(s), ${total_infos} info${RESET}"
else
  echo -e "${GREEN}🟢 All clusters healthy${RESET}"
fi
