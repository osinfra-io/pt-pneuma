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

  TEAM_ENTRIES+=("${SUBDOMAIN}")
done

if [[ ${#TEAM_ENTRIES[@]} -eq 0 ]]; then
  echo "Error: No teams with kubernetes_engine found in ${LOGOS_TEAMS_DIR}"
  exit 1
fi

# Generate URL list for a given environment.
# Args: env_short (sb|nonprod|prod)

generate_urls() {
  local ENV="${1}"
  local -a URLS=()

  local DOMAIN="osinfra.io"
  if [[ "${ENV}" != "prod" ]]; then
    DOMAIN="${ENV}.osinfra.io"
  fi

  for SERVICE in agentgateway authentik openbao; do
    URLS+=("https://${SERVICE}.${DOMAIN}")
  done

  for SUBDOMAIN in "${TEAM_ENTRIES[@]}"; do
    URLS+=("https://${SUBDOMAIN}.${DOMAIN}")
  done

  printf '%s\n' "${URLS[@]}" | sort -u
}

mkdir -p "${NUCLEI_DIR}"

generate_urls "sb"      > "${NUCLEI_DIR}/sb.txt"
generate_urls "nonprod" > "${NUCLEI_DIR}/nonprod.txt"
generate_urls "prod"    > "${NUCLEI_DIR}/prod.txt"

echo "Updated:"
for ENV in sb nonprod prod; do
  COUNT=$(wc -l < "${NUCLEI_DIR}/${ENV}.txt")
  echo "  ${NUCLEI_DIR}/${ENV}.txt (${COUNT} URLs)"
done
