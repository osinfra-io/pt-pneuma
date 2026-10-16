#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly OWNER_VALUE="osinfra-local-gateway-stack"
readonly MODE="${1:-install-and-routes}"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "AgentGateway local setup: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' was not found"
}

state_has() {
  local name="$1"
  local address="$2"

  tofu_stage "${name}" state list 2>/dev/null |
    grep --fixed-strings --line-regexp --quiet "${address}"
}

assert_state_or_absent() {
  local stage="$1"
  local address="$2"
  local resource_kind="$3"
  local resource_name="$4"
  local namespace="$5"
  local namespace_args=()

  if [ -n "${namespace}" ]; then
    namespace_args=(--namespace="${namespace}")
  fi

  if state_has "${stage}" "${address}"; then
    return
  fi

  if kubectl get "${resource_kind}" "${resource_name}" \
    "${namespace_args[@]}" --ignore-not-found --output=name |
    grep --quiet .; then
    fail "${resource_kind}/${resource_name} exists but is not in ${stage} state; explicitly import/adopt it before setup"
  fi
}

assert_routing_state_or_absent() {
  local address="$1"
  local resource_kind="$2"
  local resource_name="$3"
  local namespace="$4"

  assert_state_or_absent routing "module.agentgateway_local.${address}" \
    "${resource_kind}" "${resource_name}" "${namespace}"
}

check_release_state() {
  local release="$1"
  local address="$2"

  if helm status "${release}" --namespace=agentgateway >/dev/null 2>&1 &&
    ! state_has regional "${address}"; then
    fail "Helm release '${release}' exists but is not in regional state; explicitly import/adopt it before setup"
  fi
}

case "${MODE}" in
  all | install | routes | install-and-routes) ;;
  *) fail "usage: $0 [all|install|routes|install-and-routes]" ;;
esac

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

mkdir -p "${WORK_DIR}"
for stage in regional manifests routing; do
  tofu_stage "${stage}" init \
    -reconfigure \
    -backend-config="path=${WORK_DIR}/${stage}.tfstate" \
    -input=false
done

if [ "${MODE}" != routes ]; then
  check_release_state agentgateway 'module.agentgateway.helm_release.agentgateway'
  check_release_state agentgateway-crds 'module.agentgateway.helm_release.agentgateway_crds'

  if ! state_has regional 'module.agentgateway.kubernetes_namespace_v1.agentgateway'; then
    assert_state_or_absent regional 'kubernetes_namespace_v1.agentgateway' \
      namespace agentgateway ""
  fi
  assert_state_or_absent regional 'module.agentgateway.kubernetes_manifest.agentgateway' \
    gateway agentgateway-proxy agentgateway

  kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 ||
    fail "Gateway API CRDs are missing; deploy the local Istio/Gateway API stage first"
fi

if [ "${MODE}" != install ]; then
  kubectl get service authentik-server --namespace=authentik >/dev/null 2>&1 ||
    fail "Authentik must be ready in namespace authentik before applying routes"
  kubectl get service authentik-server --namespace=authentik \
    --output=jsonpath='{range .spec.ports[*]}{.port}{" "}{end}' |
    grep --word-regexp --quiet 80 ||
    fail "Authentik Service authentik-server must expose HTTP port 80"
  kubectl get service istio-test --namespace=istio-test >/dev/null 2>&1 ||
    fail "the diagnostic Service istio-test must be ready before applying routes"
  kubectl get gateway gateway --namespace=istio-ingress >/dev/null 2>&1 ||
    fail "the Istio ingress Gateway must be ready before applying routes"

  assert_routing_state_or_absent \
    kubernetes_manifest.agentgateway_backend httproute agentgateway-backend agentgateway
  assert_routing_state_or_absent \
    kubernetes_manifest.agentgateway_ingress httproute agentgateway-ingress agentgateway
  assert_routing_state_or_absent \
    kubernetes_manifest.agentgateway_admin httproute agentgateway-admin agentgateway
  assert_routing_state_or_absent \
    'kubernetes_manifest.authentik_outpost' httproute authentik-outpost-agentgateway authentik
  assert_routing_state_or_absent \
    'kubernetes_manifest.agentgateway_reference_grant' referencegrant agentgateway istio-test
  assert_routing_state_or_absent \
    'kubernetes_manifest.agentgateway_admin_authorization' authorizationpolicy agentgateway-admin agentgateway
  assert_routing_state_or_absent \
    'kubernetes_service_v1.agentgateway_admin' service agentgateway-proxy-admin agentgateway
fi

if [ "${MODE}" != routes ]; then
  tofu_stage regional apply -auto-approve -input=false
  kubectl wait --for=condition=Established \
    crd/agentgatewayparameters.agentgateway.dev --timeout=120s
  assert_state_or_absent manifests \
    'module.agentgateway_manifests.kubernetes_manifest.agentgateway_parameters' \
    agentgatewayparameters agentgateway-proxy agentgateway
  tofu_stage manifests apply -auto-approve -input=false
fi

if [ "${MODE}" != install ]; then
  tofu_stage routing apply -auto-approve -input=false
fi

if [ "${MODE}" = all ] || [ "${MODE}" = routes ] || [ "${MODE}" = install-and-routes ]; then
  "${SCRIPT_DIR}/verify.sh"
fi
