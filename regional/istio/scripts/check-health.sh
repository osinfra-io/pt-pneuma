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

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <env>"
  echo "  env: sb, nonprod, or prod"
  exit 1
fi

ENV="${1}"

case "${ENV}" in
  sb | nonprod | prod) ;;
  *)
    echo "Error: env must be one of: sb, nonprod, prod"
    exit 1
    ;;
esac

# Use a temporary kubeconfig — never writes to ~/.kube/config.

KUBECONFIG_FILE="$(mktemp)"
trap 'rm -f "${KUBECONFIG_FILE}"' EXIT
export KUBECONFIG="${KUBECONFIG_FILE}"

# Discover all pt-corpus projects for this environment, then find which ones
# have GKE clusters.

declare -A CLUSTER_ZONES
declare -A CLUSTER_PROJECT

echo "Discovering all projects for env '${ENV}'..."

mapfile -t PROJECTS < <(gcloud projects list \
  --filter="labels.repository=pt-corpus" \
  --format="value(projectId)" | grep "\-${ENV}$")

if [[ ${#PROJECTS[@]} -eq 0 ]]; then
  echo "Error: No pt-corpus projects found for env '${ENV}'."
  exit 1
fi

echo "Found ${#PROJECTS[@]} project(s), scanning for GKE clusters..."
echo

for PROJECT in "${PROJECTS[@]}"; do
  mapfile -t CLUSTER_ROWS < <(gcloud container clusters list \
    --project="${PROJECT}" \
    --format="csv[no-heading](name,location)" 2>/dev/null || true)

  [[ ${#CLUSTER_ROWS[@]} -eq 0 ]] && continue

  echo "  ${PROJECT}: ${#CLUSTER_ROWS[@]} cluster(s)"

  for row in "${CLUSTER_ROWS[@]}"; do
    NAME="${row%%,*}"
    ZONE="${row##*,}"
    CLUSTER_ZONES["${NAME}"]="${ZONE}"
    CLUSTER_PROJECT["${NAME}"]="${PROJECT}"
  done
done

echo

if [[ ${#CLUSTER_ZONES[@]} -eq 0 ]]; then
  echo "Error: No GKE clusters found across any pt-corpus project for env '${ENV}'."
  exit 1
fi

# Fetch credentials for all clusters into the temporary kubeconfig.

for NAME in "${!CLUSTER_ZONES[@]}"; do
  gcloud container clusters get-credentials "${NAME}" \
    --zone="${CLUSTER_ZONES[${NAME}]}" \
    --project="${CLUSTER_PROJECT[${NAME}]}" \
    --quiet
done

# Run health checks on each cluster.

for NAME in "${!CLUSTER_ZONES[@]}"; do
  PROJECT="${CLUSTER_PROJECT[${NAME}]}"
  CTX="gke_${PROJECT}_${CLUSTER_ZONES[${NAME}]}_${NAME}"

  echo "════════════════════════════════════════"
  echo "Cluster: ${NAME} [${PROJECT}]"
  echo "════════════════════════════════════════"

  echo ""
  echo "── istioctl analyze ──"
  timeout 60 istioctl analyze --context="${CTX}" 2>&1; rc=$?; [ $rc -eq 0 ] || [ $rc -eq 124 ]

  echo ""
  echo "── proxy-status ──"
  istioctl proxy-status --context="${CTX}" 2>&1

  echo ""
  echo "── remote-clusters ──"
  istioctl remote-clusters --context="${CTX}" 2>&1

  echo ""
done
