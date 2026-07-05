#!/bin/bash
set -euo pipefail

# Generate Nuclei URL target files from pt-logos team configurations.
#
# Reads all teams/*.tfvars files in pt-logos, extracts teams with a
# kubernetes_engine block, and writes one URL file per environment:
#
#   .github/workflows/nuclei/sb.txt
#   .github/workflows/nuclei/nonprod.txt
#   .github/workflows/nuclei/prod.txt
#
# Usage: ./scripts/update-nuclei-urls.sh
#   Run from the root of pt-pneuma, or via pre-commit (repo: local).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOGOS_TEAMS_DIR="${REPO_ROOT}/../../logos/pt-logos/teams"
NUCLEI_DIR="${REPO_ROOT}/.github/workflows/nuclei"

if [[ ! -d "${LOGOS_TEAMS_DIR}" ]]; then
  echo "Warning: pt-logos teams directory not found at ${LOGOS_TEAMS_DIR}"
  echo "  Ensure pt-logos is checked out alongside pt-pneuma in the platform-group workspace."
  echo "  Skipping nuclei URL update."
  exit 0
fi

# Active zones per environment (mirrors locals.tofu active_zones).

SB_ZONES=("us-east1-b" "us-east4-a")
NONPROD_ZONES=("us-east1-b" "us-east4-a")
PROD_ZONES=("us-east1-b" "us-east1-c" "us-east1-d" "us-east4-a" "us-east4-b" "us-east4-c")

# Collect team data from logos tfvars.

declare -a TEAM_ENTRIES=()

for TFVARS in "${LOGOS_TEAMS_DIR}"/*.tfvars; do
  # Skip if no kubernetes_engine block.
  if ! grep -q "kubernetes_engine" "${TFVARS}"; then
    continue
  fi

  # Extract dns_subdomain (first match inside kubernetes_engine block).
  SUBDOMAIN=$(grep 'dns_subdomain' "${TFVARS}" | head -1 | grep -o '"[^"]*"' | tr -d '"' || true)
  if [[ -z "${SUBDOMAIN}" ]]; then
    continue
  fi

  # Extract zone keys (quoted strings that look like GCP zones: region-zone, e.g. us-east1-b).
  mapfile -t ZONES < <(grep -o '"[a-z]\+-[a-z0-9]\+-[a-z]"' "${TFVARS}" | tr -d '"' | sort -u)
  if [[ ${#ZONES[@]} -eq 0 ]]; then
    continue
  fi

  TEAM_ENTRIES+=("${SUBDOMAIN} ${ZONES[*]}")
done

if [[ ${#TEAM_ENTRIES[@]} -eq 0 ]]; then
  echo "Error: No teams with kubernetes_engine found in ${LOGOS_TEAMS_DIR}"
  exit 1
fi

# Generate URL list for a given environment.
# Args: env_short (sb|nonprod|prod), active zone names

generate_urls() {
  local ENV="${1}"
  shift
  local -a ACTIVE=("$@")
  local -a URLS=()

  for ENTRY in "${TEAM_ENTRIES[@]}"; do
    read -ra PARTS <<< "${ENTRY}"
    local SUBDOMAIN="${PARTS[0]}"
    local TEAM_ZONES=("${PARTS[@]:1}")

    if [[ "${ENV}" == "prod" ]]; then
      local BASE="${SUBDOMAIN}.osinfra.io"
    else
      local BASE="${SUBDOMAIN}.${ENV}.osinfra.io"
    fi

    URLS+=("https://${BASE}")

    for ZONE in "${TEAM_ZONES[@]}"; do
      for ACTIVE_ZONE in "${ACTIVE[@]}"; do
        if [[ "${ZONE}" == "${ACTIVE_ZONE}" ]]; then
          URLS+=("https://${ZONE}.${BASE}")
          break
        fi
      done
    done
  done

  printf '%s\n' "${URLS[@]}" | sort -u
}

mkdir -p "${NUCLEI_DIR}"

generate_urls "sb"      "${SB_ZONES[@]}"      > "${NUCLEI_DIR}/sb.txt"
generate_urls "nonprod" "${NONPROD_ZONES[@]}"  > "${NUCLEI_DIR}/nonprod.txt"
generate_urls "prod"    "${PROD_ZONES[@]}"     > "${NUCLEI_DIR}/prod.txt"

echo "Updated:"
for ENV in sb nonprod prod; do
  COUNT=$(wc -l < "${NUCLEI_DIR}/${ENV}.txt")
  echo "  ${NUCLEI_DIR}/${ENV}.txt (${COUNT} URLs)"
done
