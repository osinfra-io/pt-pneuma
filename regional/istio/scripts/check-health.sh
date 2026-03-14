#!/bin/bash
set -euo pipefail

# Check Istio health across all pt-pneuma clusters.

CONTEXTS=$(kubectl config get-contexts -o name | grep "^gke_pt-pneuma")

if [[ -z "${CONTEXTS}" ]]; then
  echo "Error: No pt-pneuma kube contexts found."
  exit 1
fi

mapfile -t CONTEXT_ARRAY <<< "${CONTEXTS}"

for CTX in "${CONTEXT_ARRAY[@]}"; do
  CLUSTER_NAME="${CTX##*_}"

  echo "════════════════════════════════════════"
  echo "Cluster: ${CLUSTER_NAME}"
  echo "════════════════════════════════════════"

  echo ""
  echo "── istioctl analyze ──"
  istioctl analyze --context="${CTX}" 2>&1

  echo ""
  echo "── proxy-status ──"
  istioctl proxy-status --context="${CTX}" 2>&1

  echo ""
done
