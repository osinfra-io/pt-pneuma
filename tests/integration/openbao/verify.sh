#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "OpenBao local verification: $*" >&2
  exit 1
}

curl_status() {
  curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --output /dev/null \
    --write-out '%{http_code}' "$@"
}

expect_status() {
  local expected="$1"
  local url="$2"
  shift 2
  local actual

  actual="$(curl_status "$@" "${url}")"
  [ "${actual}" = "${expected}" ] || fail "${url} returned HTTP ${actual}; expected ${expected}"
}

wait_for_route_parent() {
  for _ in $(seq 1 90); do
    local conditions
    conditions="$(kubectl get httproute openbao --namespace=openbao \
      --output=jsonpath="{range .status.parents[*]}{.parentRef.name}{'|'}{.conditions[?(@.type=='Accepted')].status}{'|'}{.conditions[?(@.type=='ResolvedRefs')].status}{'\\n'}{end}" \
      2>/dev/null | awk -F'|' '$1 == "gateway" { print $2 "|" $3; exit }' || true)"
    if [ "${conditions}" = "True|True" ]; then
      return
    fi
    sleep 2
  done

  kubectl get httproute openbao --namespace=openbao --output=yaml >&2 || true
  fail "HTTPRoute openbao/openbao did not become Accepted and ResolvedRefs on istio-ingress/gateway"
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker does not match"

wait_for_route_parent

kubectl wait pod/openbao-0 --namespace=openbao --for=condition=Ready --timeout=180s
kubectl rollout status deployment/openbao-agent-injector --namespace=openbao --timeout=180s

pods="$(
  kubectl get pods --namespace=openbao \
    --output=jsonpath='{.items[*].metadata.name}'
)"
[ -n "${pods}" ] || fail "OpenBao pods were not found"
for pod in ${pods}; do
  kubectl wait --namespace=openbao "pod/${pod}" \
    --for=jsonpath='{.metadata.annotations.ambient\.istio\.io/redirection}'=enabled \
    --timeout=120s
  if kubectl get pod "${pod}" --namespace=openbao \
    --output=jsonpath='{.spec.containers[*].name} {.spec.initContainers[*].name}' |
    grep --quiet --word-regexp istio-proxy; then
    fail "OpenBao pod ${pod} unexpectedly has an Istio sidecar"
  fi
done

# /v1/sys/health is 200 only for an initialized, unsealed, active node.
expect_status 200 https://openbao.localhost/v1/sys/health
expect_status 200 https://openbao.localhost/ui/
expect_status 403 https://openbao.localhost/v1/sys/mounts
expect_status 403 https://openbao.localhost/v1/sys/mounts \
  --header 'X-Vault-Token: forged'

python3 "${SCRIPT_DIR}/verify-access.py"

echo "OpenBao automated checks passed. Google-backed Authentik UI and CLI sign-in remains a manual browser check."
