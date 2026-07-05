#!/bin/bash
set -euo pipefail

# Validate istio-test endpoints for all clusters in an environment.
#
# Endpoints are discovered from DNS A records in the team's Cloud DNS managed
# zone. For each zonal record the script checks /istio-test/metadata/cluster-name
# and validates the returned name contains the expected zone. The global endpoint
# is checked for HTTP 200 on /istio-test/health.
#
# Usage: ./check-endpoints.sh <env> <subdomain>
#   env:        sb (sandbox), nonprod (non-production), prod (production)
#   subdomain:  DNS subdomain for the team (e.g. pneuma, ethos)

if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <env> <subdomain>"
  echo "  env:        sb, nonprod, or prod"
  echo "  subdomain:  DNS subdomain for the team (e.g. pneuma, ethos)"
  exit 1
fi

ENV="${1}"
SUBDOMAIN="${2}"

case "${ENV}" in
  sb | nonprod | prod) ;;
  *)
    echo "Error: env must be one of: sb, nonprod, prod"
    exit 1
    ;;
esac

# Build the base domain and managed zone name for this environment.

if [[ "${ENV}" == "prod" ]]; then
  BASE_DOMAIN="${SUBDOMAIN}.osinfra.io"
  MANAGED_ZONE="${SUBDOMAIN}-osinfra-io"
else
  BASE_DOMAIN="${SUBDOMAIN}.${ENV}.osinfra.io"
  MANAGED_ZONE="${SUBDOMAIN}-${ENV}-osinfra-io"
fi

echo "Environment:   ${ENV}"
echo "Subdomain:     ${SUBDOMAIN}"
echo "Base domain:   ${BASE_DOMAIN}"
echo "Managed zone:  ${MANAGED_ZONE}"
echo

# Find the pt-corpus shared VPC host project that owns the DNS zone.

echo "Discovering DNS project for env '${ENV}'..."

DNS_PROJECT=$(gcloud projects list \
  --filter="labels.team=pt-corpus labels.repository=pt-corpus" \
  --format="value(projectId)" | grep "\-${ENV}$")

if [[ -z "${DNS_PROJECT}" ]]; then
  echo "Error: No pt-corpus project found for env '${ENV}'."
  exit 1
fi

echo "DNS project: ${DNS_PROJECT}"
echo

# Discover endpoints from DNS A records in the managed zone.

echo "Listing DNS A records..."

mapfile -t RECORDS < <(gcloud dns record-sets list \
  --zone="${MANAGED_ZONE}" \
  --project="${DNS_PROJECT}" \
  --filter="type=A" \
  --format="csv[no-heading](name)" | sort)

if [[ ${#RECORDS[@]} -eq 0 ]]; then
  echo "Error: No A records found in managed zone '${MANAGED_ZONE}'."
  exit 1
fi

echo "Found ${#RECORDS[@]} A record(s):"

for RECORD in "${RECORDS[@]}"; do
  echo "  - ${RECORD}"
done

echo

# Check endpoints.

PASS=0
FAIL=0
BODY_FILE=$(mktemp)
trap 'rm -f "${BODY_FILE}"' EXIT

for RECORD in "${RECORDS[@]}"; do
  # Strip trailing dot from DNS record name.
  HOST="${RECORD%.}"

  # Determine if this is the global endpoint or a zonal endpoint.
  # Global: {base_domain} — check /istio-test/health for HTTP 200.
  # Zonal:  {zone}.{base_domain} — check /istio-test/metadata/cluster-name.

  if [[ "${HOST}" == "${BASE_DOMAIN}" ]]; then
    URL="https://${HOST}/istio-test/metadata/cluster-name"

    echo "── ${URL} (global) ──"

    HTTP_CODE=$(curl -s -o "${BODY_FILE}" -w "%{http_code}" --connect-timeout 10 --max-time 15 "${URL}" 2>&1) || true
    BODY=$(cat "${BODY_FILE}" 2>/dev/null) || true

    if [[ "${HTTP_CODE}" != "200" ]]; then
      echo "  FAIL: HTTP ${HTTP_CODE}"
      [[ -n "${BODY}" ]] && echo "  Body: ${BODY}"
      FAIL=$((FAIL + 1))
    else
      CLUSTER_NAME=$(echo "${BODY}" | grep -o '"cluster-name":"[^"]*"' | cut -d'"' -f4) || true

      if [[ "${CLUSTER_NAME}" == *"${SUBDOMAIN}"* ]]; then
        echo "  PASS: cluster-name=${CLUSTER_NAME}"
        PASS=$((PASS + 1))
      else
        echo "  FAIL: cluster-name '${CLUSTER_NAME}' does not contain subdomain '${SUBDOMAIN}'"
        FAIL=$((FAIL + 1))
      fi
    fi
  else
    # Extract the zone prefix (everything before .{base_domain}).
    ZONE="${HOST%.${BASE_DOMAIN}}"
    URL="https://${HOST}/istio-test/metadata/cluster-name"

    echo "── ${URL} ──"

    HTTP_CODE=$(curl -s -o "${BODY_FILE}" -w "%{http_code}" --connect-timeout 10 --max-time 15 "${URL}" 2>&1) || true
    BODY=$(cat "${BODY_FILE}" 2>/dev/null) || true

    if [[ "${HTTP_CODE}" != "200" ]]; then
      echo "  FAIL: HTTP ${HTTP_CODE}"
      [[ -n "${BODY}" ]] && echo "  Body: ${BODY}"
      FAIL=$((FAIL + 1))
    else
      CLUSTER_NAME=$(echo "${BODY}" | grep -o '"cluster-name":"[^"]*"' | cut -d'"' -f4) || true

      if [[ "${CLUSTER_NAME}" == *"${SUBDOMAIN}"* ]] && [[ "${CLUSTER_NAME}" == *"${ZONE}" ]]; then
        echo "  PASS: cluster-name=${CLUSTER_NAME}"
        PASS=$((PASS + 1))
      elif [[ "${CLUSTER_NAME}" != *"${SUBDOMAIN}"* ]]; then
        echo "  FAIL: cluster-name '${CLUSTER_NAME}' does not contain subdomain '${SUBDOMAIN}'"
        FAIL=$((FAIL + 1))
      else
        echo "  FAIL: cluster-name '${CLUSTER_NAME}' does not end with zone '${ZONE}'"
        FAIL=$((FAIL + 1))
      fi
    fi
  fi

  echo
done

# Summary.

TOTAL=$((PASS + FAIL))

echo "════════════════════════════════════════"
echo "Results: ${PASS}/${TOTAL} passed, ${FAIL}/${TOTAL} failed"
echo "════════════════════════════════════════"

if [[ "${FAIL}" -gt 0 ]]; then
  exit 1
fi
