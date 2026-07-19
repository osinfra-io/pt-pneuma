#!/bin/bash
set -euo pipefail

# Create a local kubeconfig with credentials for all GKE clusters in an environment.
# Clusters are discovered automatically across all teams by querying every
# GCP project labeled labels.repository=pt-corpus for the environment.
# Each cluster context is renamed from the default gcloud format
# (gke_{project}_{zone}_{name}) to the friendly cluster name (e.g. pt-pneuma-us-east1-b).
#
# Usage: ./create-kubeconfig.sh <env>
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
    if [[ -v CLUSTER_ZONES["${NAME}"] ]]; then
      echo "  Warning: cluster name '${NAME}' exists in both '${CLUSTER_PROJECT[${NAME}]}' and '${PROJECT}' — keeping the latter"
    fi
    CLUSTER_ZONES["${NAME}"]="${ZONE}"
    CLUSTER_PROJECT["${NAME}"]="${PROJECT}"
  done
done

echo

if [[ ${#CLUSTER_ZONES[@]} -eq 0 ]]; then
  echo "Error: No GKE clusters found across any pt-corpus project for env '${ENV}'."
  exit 1
fi

echo "Found ${#CLUSTER_ZONES[@]} cluster(s):"

for NAME in "${!CLUSTER_ZONES[@]}"; do
  echo "  - ${NAME} (${CLUSTER_ZONES[${NAME}]}) [${CLUSTER_PROJECT[${NAME}]}]"
done

echo

echo "Fetching credentials and setting friendly context names..."
echo

for NAME in "${!CLUSTER_ZONES[@]}"; do
  PROJECT="${CLUSTER_PROJECT[${NAME}]}"
  LOCATION="${CLUSTER_ZONES[${NAME}]}"
  DEFAULT_CONTEXT="gke_${PROJECT}_${LOCATION}_${NAME}"

  echo "  ${NAME}..."

  gcloud container clusters get-credentials "${NAME}" \
    --location="${LOCATION}" \
    --project="${PROJECT}" \
    --quiet

  # Rename from the default gcloud context name to the friendly cluster name.
  # Delete an existing context with the friendly name first to avoid a rename conflict.
  if kubectl config get-contexts "${NAME}" &>/dev/null; then
    kubectl config delete-context "${NAME}" &>/dev/null
  fi

  kubectl config rename-context "${DEFAULT_CONTEXT}" "${NAME}"
done

echo
echo "Kubeconfig updated. Available contexts:"
echo

for NAME in "${!CLUSTER_ZONES[@]}"; do
  echo "  kubectl config use-context ${NAME}"
done

echo
echo "Done."
