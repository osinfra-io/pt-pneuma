#!/bin/bash
set -euo pipefail

# Create Istio remote secrets for multi-cluster mesh.
# Each cluster needs a remote secret for every other cluster in the mesh.
#
# Clusters are discovered automatically across all teams by querying every
# GCP project labeled labels.repository=pt-corpus for the environment. Any
# project that has GKE clusters is included. Credentials are written to a
# temporary kubeconfig file and cleaned up on exit — nothing is written to
# ~/.kube/config.
#
# Usage: ./create-remote-secrets.sh <env>
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
# have GKE clusters. CLUSTER_ZONES maps cluster name → zone.
# CLUSTER_PROJECT maps cluster name → GCP project.

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

echo "Found ${#CLUSTER_ZONES[@]} cluster(s) total:"

for NAME in "${!CLUSTER_ZONES[@]}"; do
  echo "  - ${NAME} (${CLUSTER_ZONES[${NAME}]}) [${CLUSTER_PROJECT[${NAME}]}]"
done

echo

# Fetch credentials for all clusters into the temporary kubeconfig.

echo "Fetching credentials..."

for NAME in "${!CLUSTER_ZONES[@]}"; do
  gcloud container clusters get-credentials "${NAME}" \
    --zone="${CLUSTER_ZONES[${NAME}]}" \
    --project="${CLUSTER_PROJECT[${NAME}]}" \
    --quiet
done

echo

# Create remote secrets: for each cluster pair (source != target), generate
# a remote secret from the source and apply it to the target.

for SOURCE_NAME in "${!CLUSTER_ZONES[@]}"; do
  SOURCE_PROJECT="${CLUSTER_PROJECT[${SOURCE_NAME}]}"
  SOURCE_CTX="gke_${SOURCE_PROJECT}_${CLUSTER_ZONES[${SOURCE_NAME}]}_${SOURCE_NAME}"

  for TARGET_NAME in "${!CLUSTER_ZONES[@]}"; do
    if [[ "${SOURCE_NAME}" == "${TARGET_NAME}" ]]; then
      continue
    fi

    TARGET_PROJECT="${CLUSTER_PROJECT[${TARGET_NAME}]}"
    TARGET_CTX="gke_${TARGET_PROJECT}_${CLUSTER_ZONES[${TARGET_NAME}]}_${TARGET_NAME}"

    echo "Creating remote secret '${SOURCE_NAME}-${ENV}' → '${TARGET_NAME}'..."

    istioctl create-remote-secret \
      --context="${SOURCE_CTX}" \
      --name="${SOURCE_NAME}-${ENV}" |
      kubectl apply -f - --context="${TARGET_CTX}"

    echo
  done
done

echo "Remote secrets created successfully."
