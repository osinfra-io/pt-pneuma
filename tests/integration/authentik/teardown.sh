#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
require_local_cluster
namespace="$(kubectl --context="${KUBE_CONTEXT}" get namespace authentik --ignore-not-found --output=name)"
if [ -n "${namespace}" ] &&
  [ "$(kubectl --context="${KUBE_CONTEXT}" get namespace authentik --output=jsonpath='{.metadata.labels.app\.kubernetes\.io/managed-by}')" != "osinfra-local-gateway-stack" ]; then
  echo "The namespace is not owned by this fixture; refusing teardown." >&2
  exit 1
fi
if [ ! -f "${WORK_DIR}/runtime/terraform.tfstate" ]; then
  echo "No owned Authentik runtime state; refusing to delete existing resources." >&2
  exit 1
fi
local_tofu runtime destroy -input=false -auto-approve \
  -state="${WORK_DIR}/runtime/terraform.tfstate" \
  -var-file="${WORK_DIR}/runtime/credentials.tfvars.json"
kubectl --context="${KUBE_CONTEXT}" delete namespace authentik --ignore-not-found --wait=true --timeout=120s
for file in \
  "${WORK_DIR}/config/terraform.tfstate" \
  "${WORK_DIR}/config/terraform.tfstate.backup" \
  "${WORK_DIR}/config/bootstrap.tfvars.json"; do
  if [ -f "${file}" ]; then
    rm "${file}"
  fi
done
echo "Owned Authentik runtime, namespace, users, and PostgreSQL data removed. Configuration state cleared for fresh setup."
