#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "AgentGateway local verification: $*" >&2
  exit 1
}

expect_status() {
  local expected="$1"
  local url="$2"
  shift 2
  local actual
  actual="$(curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --output /dev/null \
    --write-out '%{http_code}' "$@" "${url}")"
  [ "${actual}" = "${expected}" ] || fail "${url} returned HTTP ${actual}; expected ${expected}"
}

wait_for_route_parent() {
  local namespace="$1"
  local route="$2"
  local parent_name="$3"
  local parent_namespace="$4"

  for _ in $(seq 1 90); do
    local parent_conditions
    parent_conditions="$(kubectl get httproute "${route}" --namespace="${namespace}" \
      --output=jsonpath="{range .status.parents[*]}{.parentRef.name}{'|'}{.parentRef.namespace}{'|'}{.conditions[?(@.type=='Accepted')].status}{'|'}{.conditions[?(@.type=='ResolvedRefs')].status}{'\\n'}{end}" \
      2>/dev/null | awk -F'|' -v name="${parent_name}" -v ns="${parent_namespace}" \
      -v route_ns="${namespace}" \
      '$1 == name && ($2 == ns || ($2 == "" && ns == route_ns)) { print $3 "|" $4; exit }' || true)"
    if [ "${parent_conditions}" = "True|True" ]; then
      return
    fi
    sleep 2
  done

  kubectl get httproute "${route}" --namespace="${namespace}" --output=yaml >&2 || true
  fail "HTTPRoute ${namespace}/${route} did not become Accepted and ResolvedRefs on ${parent_namespace}/${parent_name}"
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker does not match"

wait_for_route_parent agentgateway agentgateway-backend agentgateway-proxy agentgateway
wait_for_route_parent agentgateway agentgateway-ingress gateway istio-ingress
wait_for_route_parent agentgateway agentgateway-admin gateway istio-ingress
wait_for_route_parent authentik authentik-outpost-agentgateway gateway istio-ingress

kubectl rollout status deployment/agentgateway --namespace=agentgateway --timeout=180s
kubectl rollout status deployment/agentgateway-proxy --namespace=agentgateway --timeout=180s
kubectl wait --for=condition=Programmed gateway/agentgateway-proxy \
  --namespace=agentgateway --timeout=180s
kubectl get service authentik-server --namespace=authentik \
  --output=jsonpath='{range .spec.ports[*]}{.port}{" "}{end}' |
  grep --word-regexp --quiet 80 ||
  fail "expected Authentik Service authentik-server to expose HTTP port 80"

proxy_pods="$(
  kubectl get pods --namespace=agentgateway \
    --selector=gateway.networking.k8s.io/gateway-name=agentgateway-proxy \
    --output=jsonpath='{.items[*].metadata.name}'
)"
[ -n "${proxy_pods}" ] || fail "AgentGateway proxy pods were not found"
for pod in ${proxy_pods}; do
  kubectl wait --namespace=agentgateway "pod/${pod}" \
    --for=jsonpath='{.metadata.annotations.ambient\.istio\.io/redirection}'=enabled \
    --timeout=120s
  if kubectl get pod "${pod}" --namespace=agentgateway \
    --output=jsonpath='{.spec.containers[*].name} {.spec.initContainers[*].name}' |
    grep --quiet --word-regexp istio-proxy; then
    fail "AgentGateway proxy pod ${pod} unexpectedly has an Istio sidecar"
  fi
done

expect_status 200 https://agentgateway.localhost/agentgateway-test/health
expect_status 200 https://agentgateway.localhost/agentgateway-test/metadata/cluster-name
expect_status 204 https://agentgateway.localhost/outpost.goauthentik.io/ping

redirect_headers="$(
  curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --dump-header - --output /dev/null \
    https://agentgateway.localhost/agentgateway-test/auth
)"
grep --quiet '^HTTP/.* 302' <<<"${redirect_headers}" ||
  fail "protected diagnostic route did not redirect to Authentik"
grep --quiet '^location: https://authentik.localhost/application/o/authorize/' \
  <<<"${redirect_headers,,}" ||
  fail "diagnostic route redirect did not target authentik.localhost"
grep --quiet 'redirect_uri=https%3a%2f%2fagentgateway.localhost%2foutpost.goauthentik.io%2fcallback' \
  <<<"${redirect_headers,,}" ||
  fail "Authentik redirect did not use the agentgateway outpost callback"

expect_status 302 https://agentgateway.localhost/ui/
ui_headers="$(
  curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --dump-header - --output /dev/null \
    https://agentgateway.localhost/ui/
)"
grep --quiet '^location: https://authentik.localhost/application/o/authorize/' \
  <<<"${ui_headers,,}" || fail "AgentGateway admin UI did not redirect to Authentik"

spoofed_status="$(
  curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --output /dev/null --write-out '%{http_code}' \
    --header 'X-Authentik-Username: spoofed' \
    --header 'X-Authentik-Email: spoofed@example.com' \
    --header 'X-Authentik-Groups: admins' \
    https://agentgateway.localhost/agentgateway-test/auth
)"
[ "${spoofed_status}" = "302" ] ||
  fail "forged Authentik identity headers bypassed browser authentication"

echo "AgentGateway automated checks passed. Google sign-in and authenticated identity checks remain a manual browser step."
