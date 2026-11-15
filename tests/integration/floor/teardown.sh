#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "floor local teardown: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker is missing or belongs to another owner"

# The floor configuration is reconciled by Flux, so it is removed before the engine.
kubectl delete kustomization floor-local --namespace=flux-system \
  --ignore-not-found --timeout=180s 2>/dev/null || true

state_file="${WORK_DIR}/engine.tfstate"
if [ -f "${state_file}" ]; then
  tofu_stage engine init -reconfigure -backend-config="path=${state_file}" -input=false
  tofu_stage engine destroy -auto-approve -input=false
fi

for namespace in "${FIXTURE_NAMESPACE}" floor-system flux-system; do
  kubectl delete namespace "${namespace}" --ignore-not-found --timeout=300s
done

# The charts leave their CRDs behind, which blocks a clean reinstall.
for crd in terraforms.infra.contrib.fluxcd.io fluxinstances.fluxcd.controlplane.io; do
  kubectl delete crd "${crd}" --ignore-not-found --timeout=180s
done

rm -f "${WORK_DIR}/github-token" "${WORK_DIR}/runner-encryption.hcl" \
  "${WORK_DIR}/state-passphrase"

echo "floor-owned resources, Flux CRDs, and the local credentials were removed. The shared ownership marker was not deleted."
