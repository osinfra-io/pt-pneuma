#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
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
  if [ "${name}" = regional ]; then
    namespace="$(kubectl get namespace openbao --ignore-not-found --output=name)"
    if [ -n "${namespace}" ]; then
      tofu_stage regional state list |
        grep --fixed-strings --line-regexp --quiet kubernetes_namespace_v1.openbao ||
        fail "OpenBao namespace is not tracked in fixture state; refusing teardown"
    fi
  fi
  tofu_stage "${name}" destroy -auto-approve -input=false
done

namespace="$(kubectl get namespace openbao --ignore-not-found --output=name)"
[ -z "${namespace}" ] ||
  fail "OpenBao namespace still exists; retaining configuration state and initialization keys"

# Removing the namespace also removes the data volumes and invalidates the configuration state.
rm -f "${WORK_DIR}/config.tfstate" "${WORK_DIR}/config.tfstate.backup" \
  "${WORK_DIR}/openbao-init.json"

echo "OpenBao-owned resources, data volumes, and local initialization keys were removed. The shared ownership marker was not deleted."
