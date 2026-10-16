#!/usr/bin/env bash

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly OWNER_VALUE="osinfra-local-gateway-stack"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "OpenBao local teardown: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker is missing or belongs to another owner"

for name in routing regional; do
  state_file="${WORK_DIR}/${name}.tfstate"
  [ -f "${state_file}" ] || continue
  tofu_stage "${name}" init \
    -reconfigure \
    -backend-config="path=${state_file}" -input=false
  tofu_stage "${name}" destroy -auto-approve -input=false
done

# The namespace deletion removed the data volumes, so the old root token and unseal key are invalid.
rm -f "${WORK_DIR}/openbao-init.json"

echo "OpenBao-owned resources, data volumes, and local initialization keys were removed. The shared ownership marker was not deleted."
