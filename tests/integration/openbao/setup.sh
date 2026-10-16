#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly OWNER_VALUE="osinfra-local-gateway-stack"
readonly INIT_FILE="${WORK_DIR}/openbao-init.json"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "OpenBao local setup: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' was not found"
}

state_has() {
  local stage="$1"
  local address="$2"

  tofu_stage "${stage}" state list 2>/dev/null |
    grep --fixed-strings --line-regexp --quiet "${address}"
}

assert_state_or_absent() {
  local stage="$1"
  local address="$2"
  local resource_kind="$3"
  local resource_name="$4"
  local namespace="$5"

  if state_has "${stage}" "${address}"; then
    return
  fi

  if kubectl get "${resource_kind}" "${resource_name}" --namespace="${namespace}" \
    --ignore-not-found --output=name 2>/dev/null | grep --quiet .; then
    fail "${resource_kind}/${resource_name} exists but is not in ${stage} state; explicitly import/adopt it before setup"
  fi
}

openbao_status() {
  kubectl exec --namespace=openbao openbao-0 -- bao status -format=json 2>/dev/null || true
}

# The initial root token and unseal key stay in the ignored .work directory.
bootstrap_openbao() {
  local status

  kubectl wait --namespace=openbao pod/openbao-0 \
    --for=jsonpath='{.status.phase}'=Running --timeout=180s

  for _ in $(seq 1 30); do
    status="$(openbao_status)"
    [ -n "${status}" ] && break
    sleep 2
  done
  [ -n "${status:-}" ] || fail "OpenBao did not answer status requests"

  if [ "$(jq -r '.initialized' <<<"${status}")" = "false" ]; then
    mkdir -p "${WORK_DIR}"
    (
      umask 077
      kubectl exec --namespace=openbao openbao-0 -- \
        bao operator init -key-shares=1 -key-threshold=1 -format=json >"${INIT_FILE}.tmp"
      jq -e '.unseal_keys_b64[0] and .root_token' "${INIT_FILE}.tmp" >/dev/null
      mv "${INIT_FILE}.tmp" "${INIT_FILE}"
    ) || {
      rm -f "${INIT_FILE}.tmp"
      fail "bao operator init did not produce a complete init file"
    }
    status="$(openbao_status)"
  fi

  [ -s "${INIT_FILE}" ] ||
    fail "OpenBao is initialized but ${INIT_FILE} is missing; run tests/integration/openbao/teardown.sh to start fresh"

  if [ "$(jq -r '.sealed' <<<"${status}")" = "true" ]; then
    jq -r '.unseal_keys_b64[0]' "${INIT_FILE}" |
      kubectl exec --stdin --namespace=openbao openbao-0 -- sh -c 'read -r key && bao operator unseal "${key}"' >/dev/null
  fi

  for _ in $(seq 1 60); do
    status="$(openbao_status)"
    if [ "$(jq -r '.initialized and (.sealed | not)' <<<"${status}")" = "true" ]; then
      return
    fi
    sleep 2
  done
  fail "OpenBao did not become initialized and unsealed"
}

require_command docker
require_command kubectl
require_command helm
require_command tofu
require_command curl
require_command jq

docker info >/dev/null 2>&1 || fail "Docker daemon is not available"
assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "initialize the dedicated local gateway stack through preflight before setup"
kubectl get gateway gateway --namespace=istio-ingress >/dev/null 2>&1 ||
  fail "the Istio ingress Gateway must be ready first; run the Istio setup"

mkdir -p "${WORK_DIR}"
for stage in regional routing; do
  tofu_stage "${stage}" init \
    -reconfigure \
    -backend-config="path=${WORK_DIR}/${stage}.tfstate" \
    -input=false
done

assert_state_or_absent regional kubernetes_namespace_v1.openbao namespace openbao ""
if helm status openbao --namespace=openbao >/dev/null 2>&1 &&
  ! state_has regional 'module.openbao.helm_release.openbao'; then
  fail "Helm release 'openbao' exists but is not in regional state; explicitly import/adopt it before setup"
fi
assert_state_or_absent routing 'module.openbao_local.kubernetes_manifest.openbao' httproute openbao openbao

tofu_stage regional apply -auto-approve -input=false
bootstrap_openbao
tofu_stage routing apply -auto-approve -input=false

"${SCRIPT_DIR}/verify.sh"
