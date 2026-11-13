#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "Agent Substrate local teardown: $*" >&2
  exit 1
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker is missing or belongs to another owner"

state_file="${WORK_DIR}/regional.tfstate"
if [ -f "${state_file}" ]; then
  tofu_stage regional init -reconfigure -backend-config="path=${state_file}" -input=false
  tofu_stage regional destroy -auto-approve -input=false
fi

helm uninstall substrate-podcert --kube-context=docker-desktop --namespace=podcertificate-controller-system --ignore-not-found >/dev/null
kubectl delete namespace podcertificate-controller-system --ignore-not-found

echo "Agent Substrate-owned resources and local database data were removed. The shared ownership marker and cluster-wide CRDs were not deleted."
