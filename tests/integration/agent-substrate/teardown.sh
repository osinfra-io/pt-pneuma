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

# Only remove the certificate controller when setup created and labelled its namespace.
owned_namespaces="$(kubectl get namespace --selector="local-fixture.osinfra.io/owner=agent-substrate" --output=name)"
if grep --fixed-strings --line-regexp --quiet 'namespace/podcertificate-controller-system' <<<"${owned_namespaces}"; then
  helm uninstall substrate-podcert --kube-context=docker-desktop --namespace=podcertificate-controller-system --ignore-not-found >/dev/null
  kubectl delete namespace podcertificate-controller-system --ignore-not-found
else
  echo "Skipping substrate-podcert: its namespace is absent or not owned by this fixture."
fi

echo "Agent Substrate-owned resources and local database data were removed. The shared ownership marker and cluster-wide CRDs were not deleted."
