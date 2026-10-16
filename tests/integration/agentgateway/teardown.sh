#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "AgentGateway local teardown: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker is missing or belongs to another owner"

for name in routing manifests regional; do
  state_file="${WORK_DIR}/${name}.tfstate"
  [ -f "${state_file}" ] || continue
  tofu_stage "${name}" init \
    -reconfigure \
    -backend-config="path=${state_file}" -input=false
  tofu_stage "${name}" destroy -auto-approve -input=false
done

echo "AgentGateway-owned resources were removed from Docker Desktop. The shared ownership marker, cluster-wide CRDs, and GatewayClasses were not deleted; local state under tests/integration/agentgateway/.work was retained."
