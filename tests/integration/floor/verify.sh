#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
readonly PLAN_ID_PATTERN='^plan-main-[0-9a-f]{10}$'
readonly WAIT_SECONDS=300
readonly POLL_SECONDS=10
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

terraform_field() {
  local name="$1" path="$2"

  kubectl get terraform "${name}" --namespace="${FIXTURE_NAMESPACE}" \
    --output=jsonpath="${path}" 2>/dev/null || true
}

pending_plan() {
  terraform_field "$1" '{.status.plan.pending}'
}

ready_status() {
  terraform_field "$1" '{.status.conditions[?(@.type=="Ready")].status}'
}

ready_reason() {
  terraform_field "$1" '{.status.conditions[?(@.type=="Ready")].reason}'
}

fail_with_conditions() {
  local name="$1" message="$2"

  echo "conditions on ${FIXTURE_NAMESPACE}/${name}:" >&2
  kubectl get terraform "${name}" --namespace="${FIXTURE_NAMESPACE}" \
    --output=jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}' >&2 || true
  fail "${message}"
}

# Polls a predicate function against a Terraform object until the deadline passes.
wait_for() {
  local predicate="$1" name="$2" description="$3"
  local deadline=$((SECONDS + WAIT_SECONDS))

  while ! "${predicate}" "${name}"; do
    [ "${SECONDS}" -lt "${deadline}" ] ||
      fail_with_conditions "${name}" "timed out after ${WAIT_SECONDS}s waiting for ${description}"
    echo "waiting for ${description} ..."
    sleep "${POLL_SECONDS}"
  done
}

has_pending_plan() {
  [[ "$(pending_plan "$1")" =~ ${PLAN_ID_PATTERN} ]]
}

is_ready() {
  [ "$(ready_status "$1")" = "True" ]
}

is_applied() {
  [ -z "$(pending_plan "$1")" ] && is_ready "$1"
}

exists() {
  kubectl get terraform "$1" --namespace="${FIXTURE_NAMESPACE}" >/dev/null 2>&1
}

# Approval is a deliberate write of spec.approvePlan; Task 6 replaces this patch with floor-api.
approve_pending_plan() {
  local name="$1" plan_id

  plan_id="$(pending_plan "${name}")"
  echo "approving ${name} plan ${plan_id}"
  kubectl patch terraform "${name}" --namespace="${FIXTURE_NAMESPACE}" \
    --type=merge --field-manager=floor-api \
    --patch="{\"spec\":{\"approvePlan\":\"${plan_id}\"}}" >/dev/null ||
    fail "could not approve the ${name} plan"
}

# Flux has no health check for Terraform objects, so the Kustomization is reconciled by annotation.
reconcile_floor_kustomization() {
  local requested_at
  local deadline=$((SECONDS + WAIT_SECONDS))

  requested_at="$(date +%s)"
  kubectl annotate --overwrite kustomization floor-local --namespace=flux-system \
    "reconcile.fluxcd.io/requestedAt=${requested_at}" >/dev/null ||
    fail "could not request a reconciliation of the floor-local kustomization"

  while [ "$(kubectl get kustomization floor-local --namespace=flux-system \
    --output=jsonpath='{.status.lastHandledReconcileAt}' 2>/dev/null)" != "${requested_at}" ]; do
    [ "${SECONDS}" -lt "${deadline}" ] ||
      fail "the floor-local kustomization did not handle the reconcile request"
    echo "waiting for the floor-local kustomization to reconcile ..."
    sleep "${POLL_SECONDS}"
  done
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

# The floor configuration is reconciled from the floor repository, not applied by the stage.
for terraform_name in main-sandbox regional-sandbox; do
  wait_for exists "${terraform_name}" "the floor-local kustomization to create ${terraform_name}"
done

if is_applied main-sandbox; then
  echo "main-sandbox is already applied; skipping approval"
else
  wait_for has_pending_plan main-sandbox "a pending plan on main-sandbox"

  # The regional workspace reads what main creates, so it must not plan before main applies.
  regional_reason="$(ready_reason regional-sandbox)"
  [ "${regional_reason}" = "DependencyNotReady" ] ||
    fail_with_conditions regional-sandbox \
      "regional-sandbox reports '${regional_reason}' instead of DependencyNotReady before main-sandbox applies"

  approve_pending_plan main-sandbox
  wait_for is_ready main-sandbox "main-sandbox to become Ready"
fi

kubectl get namespace floor-fixture >/dev/null 2>&1 ||
  fail "the floor-fixture namespace was not created by main-sandbox"

# Review Focus 3: approval lives in the cluster, so Flux must never revert spec.approvePlan.
approved_plan="$(terraform_field main-sandbox '{.spec.approvePlan}')"
reconcile_floor_kustomization
[ "$(terraform_field main-sandbox '{.spec.approvePlan}')" = "${approved_plan}" ] ||
  fail "the floor-local kustomization reverted spec.approvePlan on main-sandbox"

if is_applied regional-sandbox; then
  echo "regional-sandbox is already applied; skipping approval"
else
  wait_for has_pending_plan regional-sandbox "a pending plan on regional-sandbox"
  approve_pending_plan regional-sandbox
  wait_for is_ready regional-sandbox "regional-sandbox to become Ready"
fi

kubectl get configmap regional --namespace=floor-fixture >/dev/null 2>&1 ||
  fail "the floor-fixture/regional ConfigMap was not created by regional-sandbox"

echo "floor local verification passed"
