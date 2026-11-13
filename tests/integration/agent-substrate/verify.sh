#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "Agent Substrate local verification: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker does not match"

kubectl rollout status statefulset/postgresql --namespace=ate-system --timeout=180s

deployments="$(kubectl get deployments --namespace=ate-system --output=jsonpath='{.items[*].metadata.name}')" ||
  fail "could not list deployments in ate-system"
[ -n "${deployments}" ] || fail "no deployments found in ate-system"

for deployment in ${deployments}; do
  kubectl rollout status "deployment/${deployment}" --namespace=ate-system --timeout=300s
done

echo "Agent Substrate automated checks passed."
