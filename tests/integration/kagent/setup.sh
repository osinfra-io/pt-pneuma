#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "kagent local setup: $*" >&2
  exit 1
}

for command_name in docker kubectl helm tofu; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "required command '${command_name}' was not found"
done

docker info >/dev/null 2>&1 || fail "Docker daemon is not available"
assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "initialize the dedicated local gateway stack through preflight before setup"

kubectl get deployment/ate-api-server --namespace=ate-system >/dev/null 2>&1 ||
  fail "Agent Substrate must be installed before kagent"

if helm status kagent --namespace=kagent >/dev/null 2>&1 &&
  ! tofu_stage regional state list 2>/dev/null |
    grep --fixed-strings --quiet 'module.kagent.helm_release.kagent'; then
  fail "Helm release 'kagent' exists but is not in regional state; explicitly import/adopt it before setup"
fi

mkdir -p "${WORK_DIR}"
tofu_stage regional init -reconfigure -backend-config="path=${WORK_DIR}/regional.tfstate" -input=false
tofu_stage regional apply -auto-approve -input=false

"${SCRIPT_DIR}/verify.sh"
