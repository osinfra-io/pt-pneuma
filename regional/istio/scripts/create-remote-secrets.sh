#!/bin/bash
set -euo pipefail

# Create Istio remote secrets for multi-cluster mesh.
# Each cluster needs a remote secret for every other cluster in the mesh.

  # Cluster 1 → Cluster 2 (us-east1-b secret applied to us-east4-b):

  #  istioctl create-remote-secret \
  #    --context=gke_pt-pneuma-k8s-tf10-sb_us-east1_pt-pneuma-us-east1-b \
  #    --name=pt-pneuma-us-east1-b-sb | \
  #    kubectl apply -f - --context=gke_pt-pneuma-k8s-tf10-sb_us-east4_pt-pneuma-us-east4-b

  # Cluster 2 → Cluster 1 (us-east4-b secret applied to us-east1-b):

  #  istioctl create-remote-secret \
  #    --context=gke_pt-pneuma-k8s-tf10-sb_us-east4_pt-pneuma-us-east4-b \
  #    --name=pt-pneuma-us-east4-b-sb | \
  #    kubectl apply -f - --context=gke_pt-pneuma-k8s-tf10-sb_us-east1_pt-pneuma-us-east1-b

CONTEXTS=$(kubectl config get-contexts -o name | grep "^gke_pt-pneuma")

if [[ -z "${CONTEXTS}" ]]; then
  echo "Error: No pt-pneuma kube contexts found."
  exit 1
fi

mapfile -t CONTEXT_ARRAY <<< "${CONTEXTS}"

echo "Found ${#CONTEXT_ARRAY[@]} cluster context(s):"
for ctx in "${CONTEXT_ARRAY[@]}"; do
  echo "  - ${ctx}"
done
echo

for SOURCE_CTX in "${CONTEXT_ARRAY[@]}"; do
  # Extract cluster name (last segment) and env (from project segment)
  # Context format: gke_<project>_<region>_<cluster-name>
  CLUSTER_NAME="${SOURCE_CTX##*_}"
  PROJECT="${SOURCE_CTX#gke_}"
  PROJECT="${PROJECT%%_*}"
  ENV="${PROJECT##*-}"

  REMOTE_NAME="${CLUSTER_NAME}-${ENV}"

  for TARGET_CTX in "${CONTEXT_ARRAY[@]}"; do
    if [[ "${SOURCE_CTX}" == "${TARGET_CTX}" ]]; then
      continue
    fi

    echo "Creating remote secret '${REMOTE_NAME}' from context '${SOURCE_CTX}' and applying to '${TARGET_CTX}'..."

    istioctl create-remote-secret \
      --context="${SOURCE_CTX}" \
      --name="${REMOTE_NAME}" | \
      kubectl apply -f - --context="${TARGET_CTX}"

    echo
  done
done

echo "Remote secrets created successfully."
