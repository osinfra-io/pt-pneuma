#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "floor local verification: $*" >&2
  exit 1
}

assert_secret_key() {
  local namespace="$1" name="$2" key="$3"

  kubectl get secret "${name}" --namespace="${namespace}" \
    --output=jsonpath="{.data.${key}}" 2>/dev/null | grep --quiet . ||
    fail "secret ${namespace}/${name} is missing key ${key}"
}

assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "cluster ownership marker does not match"

# Flux and tofu-controller run off the ambient mesh.
dataplane_mode="$(kubectl get namespace flux-system \
  --output=jsonpath='{.metadata.labels.istio\.io/dataplane-mode}' 2>/dev/null)" ||
  fail "the flux-system namespace was not found"
[ -z "${dataplane_mode}" ] ||
  fail "the flux-system namespace carries istio.io/dataplane-mode=${dataplane_mode}"

for deployment in flux-operator source-controller kustomize-controller \
  notification-controller tofu-controller tofu-controller-branch-planner; do
  kubectl rollout status "deployment/${deployment}" --namespace=flux-system --timeout=180s ||
    fail "deployment ${deployment} did not become available"
done

kubectl get crd terraforms.infra.contrib.fluxcd.io >/dev/null 2>&1 ||
  fail "the terraforms.infra.contrib.fluxcd.io CRD is missing"

assert_secret_key flux-system branch-planner-token token
assert_secret_key "${FIXTURE_NAMESPACE}" floor-runner-env TF_ENCRYPTION

config_map_secret_name="$(kubectl get configmap branch-planner --namespace=flux-system \
  --output=jsonpath='{.data.secretName}' 2>/dev/null)" ||
  fail "the flux-system/branch-planner ConfigMap was not found"
[ "${config_map_secret_name}" = "branch-planner-token" ] ||
  fail "the branch-planner ConfigMap references secret '${config_map_secret_name}'"

kubectl get configmap branch-planner --namespace=flux-system \
  --output=jsonpath='{.data.resources}' 2>/dev/null |
  grep --quiet "namespace: ${FIXTURE_NAMESPACE}" ||
  fail "the branch-planner ConfigMap does not watch ${FIXTURE_NAMESPACE}"

echo "floor local verification passed"
