#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "kagent local verification: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker does not match"

kubectl rollout status statefulset/postgresql --namespace=kagent --timeout=180s

for deployment in $(kubectl get deployments --namespace=kagent --output=jsonpath='{.items[*].metadata.name}'); do
  kubectl rollout status "deployment/${deployment}" --namespace=kagent --timeout=300s
done

expect_header() {
  local url="$1" pattern="$2" headers
  headers="$(curl --noproxy '*' --connect-timeout 5 --max-time 15 \
    --insecure --silent --show-error --dump-header - --output /dev/null "${url}")"
  grep --quiet '^HTTP/.* 302' <<<"${headers}" || fail "${url} did not redirect"
  grep --quiet "${pattern}" <<<"${headers,,}" || fail "${url} redirect did not match ${pattern}"
}

expect_header https://kagent.localhost/ '^location: https://authentik.localhost/application/o/authorize/'
expect_header https://kagent.localhost/ 'redirect_uri=https%3a%2f%2fkagent.localhost%2foutpost.goauthentik.io%2fcallback'

echo "kagent automated checks passed."
