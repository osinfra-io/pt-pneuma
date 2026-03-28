#!/bin/bash
set -euo pipefail

# Create Istio remote secrets for multi-cluster mesh.
# Each cluster needs a remote secret for every other cluster in the mesh.
#
# Clusters are discovered via gcloud. Credentials are written to a temporary
# kubeconfig file and cleaned up on exit — nothing is written to ~/.kube/config.
#
# Usage: ./create-remote-secrets.sh <env> [team]
#   env:  sb (sandbox), nonprod (non-production), prod (production)
#   team: team label used to find the Kubernetes project (default: pt-pneuma)

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <env> [team]"
  echo "  env:  sb, nonprod, or prod"
  echo "  team: labels.team value used to find the Kubernetes project (default: pt-pneuma)"
  exit 1
fi

ENV="${1}"
TEAM="${2:-pt-pneuma}"

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

# Discover the Kubernetes project for this team and environment.
# Project IDs follow the pattern: {team}-k8s-{random}-{env}

echo "Discovering ${TEAM} Kubernetes project for env '${ENV}'..."

PROJECT=$(gcloud projects list \
  --filter="labels.team=${TEAM} labels.repository=pt-corpus" \
  --format="value(projectId)" | grep "\-${ENV}$")

if [[ -z "${PROJECT}" ]]; then
  echo "Error: No ${TEAM} Kubernetes project found for env '${ENV}'."
  exit 1
fi

echo "Project: ${PROJECT}"
echo

# Discover all GKE clusters in the project.

echo "Listing clusters..."

mapfile -t CLUSTER_ROWS < <(gcloud container clusters list \
  --project="${PROJECT}" \
  --format="csv[no-heading](name,location)")

if [[ ${#CLUSTER_ROWS[@]} -eq 0 ]]; then
  echo "Error: No clusters found in project '${PROJECT}'."
  exit 1
fi

declare -A CLUSTER_ZONES

for row in "${CLUSTER_ROWS[@]}"; do
  NAME="${row%%,*}"
  ZONE="${row##*,}"
  CLUSTER_ZONES["${NAME}"]="${ZONE}"
done

echo "Found ${#CLUSTER_ROWS[@]} cluster(s):"

for NAME in "${!CLUSTER_ZONES[@]}"; do
  echo "  - ${NAME} (${CLUSTER_ZONES[${NAME}]})"
done

echo

# Fetch credentials for all clusters into the temporary kubeconfig.

echo "Fetching credentials..."

for NAME in "${!CLUSTER_ZONES[@]}"; do
  gcloud container clusters get-credentials "${NAME}" \
    --zone="${CLUSTER_ZONES[${NAME}]}" \
    --project="${PROJECT}" \
    --quiet
done

echo

# Create remote secrets: for each cluster pair (source != target), generate
# a remote secret from the source and apply it to the target.

for SOURCE_NAME in "${!CLUSTER_ZONES[@]}"; do
  SOURCE_CTX="gke_${PROJECT}_${CLUSTER_ZONES[${SOURCE_NAME}]}_${SOURCE_NAME}"

  for TARGET_NAME in "${!CLUSTER_ZONES[@]}"; do
    if [[ "${SOURCE_NAME}" == "${TARGET_NAME}" ]]; then
      continue
    fi

    TARGET_CTX="gke_${PROJECT}_${CLUSTER_ZONES[${TARGET_NAME}]}_${TARGET_NAME}"

    echo "Creating remote secret '${SOURCE_NAME}-${ENV}' → '${TARGET_NAME}'..."

    istioctl create-remote-secret \
      --context="${SOURCE_CTX}" \
      --name="${SOURCE_NAME}-${ENV}" |
      kubectl apply -f - --context="${TARGET_CTX}"

    echo
  done
done

echo "Remote secrets created successfully."
