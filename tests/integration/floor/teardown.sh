#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
readonly AUTHENTIK_BOOTSTRAP_FILE="${SCRIPT_DIR}/../authentik/.work/config/bootstrap.tfvars.json"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "floor local teardown: $*" >&2
  exit 1
}

# The authentik provider reaches the admin API over a loopback forward.
readonly AUTHENTIK_PORT=19444

start_authentik_forward() {
  kubectl port-forward --namespace=authentik --address=127.0.0.1 \
    service/authentik-server "${AUTHENTIK_PORT}:443" \
    >"${WORK_DIR}/authentik-port-forward.log" 2>&1 &
  AUTHENTIK_FORWARD_PID=$!
  trap 'kill "${AUTHENTIK_FORWARD_PID}" 2>/dev/null || true' EXIT

  for _ in $(seq 1 30); do
    if curl --noproxy '*' --fail --insecure --silent --connect-timeout 2 --max-time 5 \
      "https://127.0.0.1:${AUTHENTIK_PORT}/-/health/live/" >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done

  fail "timed out waiting for the authentik admin endpoint on 127.0.0.1:${AUTHENTIK_PORT}"
}


assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker is missing or belongs to another owner"

# floor-api and the verification identity are removed before the engine they read.
destroy_stage() {
  local stage="$1"
  shift
  local state_file="${WORK_DIR}/${stage}.tfstate"

  [ -f "${state_file}" ] || return 0
  tofu_stage "${stage}" init -reconfigure -backend-config="path=${state_file}" -input=false || return 0
  tofu_stage "${stage}" destroy -auto-approve -input=false "$@" || true
}

destroy_stage api -var="github_token_checksum=unused"

if [ -s "${AUTHENTIK_BOOTSTRAP_FILE}" ]; then
  TF_VAR_authentik_token="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["authentik_token"])' \
    "${AUTHENTIK_BOOTSTRAP_FILE}")"
  export TF_VAR_authentik_token
  start_authentik_forward
  destroy_stage auth \
    -var="authentik_url=https://127.0.0.1:${AUTHENTIK_PORT}" \
    -var="token_file=${WORK_DIR}/auth/verify-token" \
    -var="visitor_token_file=${WORK_DIR}/auth/visitor-token"
fi

# The floor configuration is reconciled by Flux, so it is removed before the engine.
kubectl delete kustomization floor-local --namespace=flux-system \
  --ignore-not-found --timeout=180s 2>/dev/null || true

# Terraform objects carry a tofu-controller finalizer, so they are deleted while the
# controller is still running; otherwise the fixture namespace stalls in Terminating
# once the engine stage removes the controller that would clear them.
kubectl delete terraforms --all --namespace="${FIXTURE_NAMESPACE}" \
  --ignore-not-found --timeout=180s 2>/dev/null || true

kubectl get terraforms --namespace="${FIXTURE_NAMESPACE}" --output=name 2>/dev/null |
  while read -r object; do
    kubectl patch "${object}" --namespace="${FIXTURE_NAMESPACE}" --type=merge \
      --patch='{"metadata":{"finalizers":null}}' 2>/dev/null || true
  done || true

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

# The local state files hold the authentik app passwords in plaintext.
rm -f "${WORK_DIR}/auth/verify-token" "${WORK_DIR}/auth/visitor-token" "${WORK_DIR}/github-token" \
  "${WORK_DIR}/runner-encryption.hcl" "${WORK_DIR}/state-passphrase"
rm -f "${WORK_DIR}"/*.tfstate*

echo "floor-owned resources, Flux CRDs, and the local credentials were removed. The shared ownership marker was not deleted."
