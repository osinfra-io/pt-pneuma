#!/usr/bin/env bash

set -euo pipefail

readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
readonly PLAN_ID_PATTERN='^plan-.+-[0-9a-f]{10}$'
readonly WAIT_SECONDS=300
readonly POLL_SECONDS=10
readonly FIXTURE_REPO="osinfra-io/pt-techne-floor-fixture"
readonly MCP_URL="https://floor.localhost/mcp"
readonly MERGE_WAIT_SECONDS=120
readonly VERIFY_USER="floor-verify"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly VERIFY_TOKEN_FILE="${SCRIPT_DIR}/.work/auth/verify-token"
readonly VISITOR_USER="floor-visitor"
readonly VISITOR_TOKEN_FILE="${SCRIPT_DIR}/.work/auth/visitor-token"
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

# A workspace that returns to main either plans a change or reconciles with no changes.
settled() {
  has_pending_plan "$1" || is_applied "$1"
}

# Settled is only meaningful once the workspace has observed the merged main
# revision; before that it still reports the previous pull request's status.
settled_at_merged_main() {
  [ "$(terraform_field "$1" '{.status.lastAttemptedRevision}')" = "${MERGED_REVISION}" ] && settled "$1"
}

exists() {
  kubectl get terraform "$1" --namespace="${FIXTURE_NAMESPACE}" >/dev/null 2>&1
}

# Every approval goes through floor-api, which the authentik outpost authenticates
# with the verification user's app password and whose identity headers it forwards.
mcp_call() {
  local tool="$1" arguments="${2-}" response status body
  local user="${MCP_USER:-${VERIFY_USER}}"
  local token_file="${MCP_TOKEN_FILE:-${VERIFY_TOKEN_FILE}}"

  [ -n "${arguments}" ] || arguments='{}'

  [ -s "${token_file}" ] ||
    fail "the app password ${token_file} is missing; run setup.sh"

  response="$(curl --noproxy '*' --insecure --silent --show-error --max-time 300 \
    --write-out '\n%{http_code}' \
    --user "${user}:$(cat "${token_file}")" \
    --header 'Accept: application/json, text/event-stream' \
    --header 'Content-Type: application/json' \
    --data "$(printf '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"%s","arguments":%s}}' \
      "${tool}" "${arguments}")" \
    "${MCP_URL}")" || fail "could not reach floor-api at ${MCP_URL}"

  status="${response##*$'\n'}"
  body="${response%$'\n'*}"

  if [ "${status}" = "302" ] || [[ "${body}" == "<"* ]]; then
    echo "${status}: ${body}" >&2
    fail "authentik outpost did not accept Basic auth; stop and report"
  fi

  [ "${status}" = "200" ] || {
    echo "${body}" >&2
    fail "floor-api returned HTTP ${status} for ${tool}"
  }

  # The streamable HTTP transport answers with JSON or server-sent events.
  MCP_RESPONSE="$(printf '%s\n' "${body}" | sed -n 's/^data: //p; /^{/p' | head -1)"
  [ -n "${MCP_RESPONSE}" ] || {
    echo "${body}" >&2
    fail "floor-api returned no JSON-RPC payload for ${tool}"
  }

  jq --exit-status 'has("result")' >/dev/null <<<"${MCP_RESPONSE}" || {
    echo "${MCP_RESPONSE}" >&2
    fail "floor-api returned a JSON-RPC error for ${tool}"
  }
}

mcp_text() {
  jq --raw-output '[.result.content[]? | select(.type == "text") | .text] | join("")' <<<"${MCP_RESPONSE}"
}

mcp_is_error() {
  [ "$(jq --raw-output '.result.isError // false' <<<"${MCP_RESPONSE}")" = "true" ]
}

mcp_ok() {
  mcp_call "$@"
  ! mcp_is_error || {
    mcp_text >&2
    fail "the $1 tool returned an error"
  }
}

approve_pending_plan() {
  local name="$1" plan_id

  plan_id="$(pending_plan "${name}")"
  echo "approving ${name} plan ${plan_id}"
  mcp_ok approve "$(jq --null-input --compact-output --arg name "${name}" --arg plan "${plan_id}" \
    '{name: $name, planId: $plan}')"
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

# floor-api is the only approval path, so nothing else is checked until it answers.
mcp_ok list_workspaces
workspaces="$(mcp_text)"
for terraform_name in main-sandbox regional-sandbox; do
  grep --fixed-strings --quiet "${terraform_name}" <<<"${workspaces}" ||
    fail "list_workspaces did not report ${terraform_name}"
done
echo "floor-api listed the floor workspaces as ${VERIFY_USER}"

# Opted-in real workspaces are read-only verification targets, never fixtures to approve.
if [ -n "${FLOOR_ADDITIONAL_NAMESPACES:-}" ]; then
  while IFS= read -r namespace; do
    names="$(jq --raw-output --arg namespace "${namespace}" \
      '.workspaces[] | select(.namespace == $namespace) | .name' <<<"${workspaces}")"
    [ -n "${names}" ] || fail "list_workspaces did not report any workspace in ${namespace}"

    while IFS= read -r name; do
      mcp_ok get_workspace "$(jq --null-input --compact-output --arg name "${name}" '{name: $name}')"
      echo "floor-api exposed ${name} without approving it"
    done <<<"${names}"

    if kubectl auth can-i get secrets --namespace="${namespace}" \
      --as=system:serviceaccount:floor-system:floor-api --quiet; then
      fail "floor-api must not have access to Secrets in ${namespace}"
    fi
  done < <(printf '%s' "${FLOOR_ADDITIONAL_NAMESPACES}" |
    jq --raw-input --raw-output 'split(",")[] | gsub("^\\s+|\\s+$"; "") | select(length > 0)')
fi

wait_for settled main-sandbox "main-sandbox to settle"

if has_pending_plan main-sandbox; then
  # The regional workspace reads what main creates, so it must not plan before main applies.
  regional_reason="$(ready_reason regional-sandbox)"
  [ "${regional_reason}" = "DependencyNotReady" ] ||
    fail_with_conditions regional-sandbox \
      "regional-sandbox reports '${regional_reason}' instead of DependencyNotReady before main-sandbox applies"

  approve_pending_plan main-sandbox
  wait_for is_ready main-sandbox "main-sandbox to become Ready"
else
  echo "main-sandbox is already applied; skipping approval"
fi

kubectl get namespace floor-fixture >/dev/null 2>&1 ||
  fail "the floor-fixture namespace was not created by main-sandbox"

# Review Focus 3: approval lives in the cluster, so Flux must never revert spec.approvePlan.
approved_plan="$(terraform_field main-sandbox '{.spec.approvePlan}')"
reconcile_floor_kustomization
[ "$(terraform_field main-sandbox '{.spec.approvePlan}')" = "${approved_plan}" ] ||
  fail "the floor-local kustomization reverted spec.approvePlan on main-sandbox"

wait_for settled regional-sandbox "regional-sandbox to settle"

if has_pending_plan regional-sandbox; then
  approve_pending_plan regional-sandbox
  wait_for is_ready regional-sandbox "regional-sandbox to become Ready"
else
  echo "regional-sandbox is already applied; skipping approval"
fi

kubectl get configmap regional --namespace=floor-fixture >/dev/null 2>&1 ||
  fail "the floor-fixture/regional ConfigMap was not created by regional-sandbox"

# Review Focus: the sandbox round trip, from a real pull request to an applied change.
branch="floor-test-$(date +%s)"
main_sha="$(gh api "repos/${FIXTURE_REPO}/git/ref/heads/main" --jq '.object.sha')" ||
  fail "could not read the fixture repository's main branch"

gh api "repos/${FIXTURE_REPO}/git/refs" --method=POST \
  --field="ref=refs/heads/${branch}" --field="sha=${main_sha}" >/dev/null ||
  fail "could not create the branch ${branch}"

pull_request=""
cleanup_pull_request() {
  [ -z "${pull_request}" ] ||
    gh pr close "${pull_request}" --repo="${FIXTURE_REPO}" >/dev/null 2>&1 || true
  gh api "repos/${FIXTURE_REPO}/git/refs/heads/${branch}" --method=DELETE >/dev/null 2>&1 || true
}
trap cleanup_pull_request EXIT

file_sha="$(gh api "repos/${FIXTURE_REPO}/contents/regional/main.tofu?ref=${branch}" --jq '.sha')" ||
  fail "could not read regional/main.tofu"

head_sha="$(gh api "repos/${FIXTURE_REPO}/contents/regional/main.tofu" --method=PUT \
  --field="branch=${branch}" \
  --field="content=$(gh api "repos/${FIXTURE_REPO}/contents/regional/main.tofu?ref=${branch}" --jq '.content' |
    base64 --decode | sed "s/workspace = \"[^\"]*\"/workspace = \"${branch}\"/" | base64 | tr --delete '\n')" \
  --field="message=Change the regional workspace value for ${branch}" \
  --field="sha=${file_sha}" --jq '.commit.sha')" ||
  fail "could not change regional/main.tofu on ${branch}"

pull_request="$(gh pr create --repo="${FIXTURE_REPO}" --base=main --head="${branch}" \
  --title="Change the regional workspace value" \
  --body="Opened by the floor local verification." |
  grep --only-matching '[0-9][0-9]*$' | tail -1)" ||
  fail "could not open a pull request for ${branch}"

echo "opened pull request ${pull_request} for ${branch} at ${head_sha}"

planner_name=""
planner_deadline=$((SECONDS + WAIT_SECONDS))
while [ -z "${planner_name}" ]; do
  planner_name="$(kubectl get terraform --namespace="${FIXTURE_NAMESPACE}" \
    --selector="infra.weave.works/pr-id=${pull_request},infra.weave.works/primary-resource=regional-sandbox" \
    --output=jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
  [ -n "${planner_name}" ] && break
  [ "${SECONDS}" -lt "${planner_deadline}" ] || {
    kubectl logs deployment/tofu-controller-branch-planner --namespace=flux-system --tail=50 >&2 || true
    fail "the Branch Planner did not create a planner object for pull request ${pull_request}"
  }
  echo "waiting for the Branch Planner to plan pull request ${pull_request} ..."
  sleep "${POLL_SECONDS}"
done

echo "the Branch Planner created ${planner_name}"

# The pull request only touches ./regional, so the main workspace must not be planned.
[ -z "$(kubectl get terraform --namespace="${FIXTURE_NAMESPACE}" \
  --selector="infra.weave.works/pr-id=${pull_request},infra.weave.works/primary-resource=main-sandbox" \
  --output=jsonpath='{.items[*].metadata.name}' 2>/dev/null)" ] ||
  fail "the Branch Planner planned main-sandbox for a change under ./regional"

wait_for has_pending_plan "${planner_name}" "a pending plan on ${planner_name}"
planner_plan="$(pending_plan "${planner_name}")"

pull_request_comments() {
  gh pr view "${pull_request}" --repo="${FIXTURE_REPO}" --json=comments --jq '.comments[].body' 2>/dev/null || true
}

# The plan comment is written after the planner object reports its plan.
comment_deadline=$((SECONDS + WAIT_SECONDS))
while ! pull_request_comments | grep --quiet 'tf-controller plan output'; do
  [ "${SECONDS}" -lt "${comment_deadline}" ] ||
    fail "the Branch Planner did not comment a plan on pull request ${pull_request}"
  echo "waiting for the Branch Planner plan comment ..."
  sleep "${POLL_SECONDS}"
done

mcp_ok pending_approvals
grep --fixed-strings --quiet "${planner_name}" <<<"$(mcp_text)" ||
  fail "pending_approvals did not report ${planner_name}"

# Review Focus 2: a stale plan id is never approved.
mcp_call approve "$(jq --null-input --compact-output --arg name "${planner_name}" \
  '{name: $name, planId: "plan-stale-0000000000"}')"
mcp_is_error || fail "floor-api approved a stale plan id"
stale_message="$(mcp_text)"
grep --quiet 'plan id mismatch' <<<"${stale_message}" ||
  fail "floor-api did not report a plan mismatch for a stale plan id"
grep --quiet "call replan on ${planner_name}" <<<"${stale_message}" ||
  fail "floor-api did not point at a replan for a stale plan id"

# An authenticated caller outside the approver group never mutates a workspace.
MCP_USER="${VISITOR_USER}"
MCP_TOKEN_FILE="${VISITOR_TOKEN_FILE}"
mcp_call approve "$(jq --null-input --compact-output --arg name "${planner_name}" --arg plan "${planner_plan}" \
  '{name: $name, planId: $plan}')"
unset MCP_USER MCP_TOKEN_FILE
mcp_is_error || fail "floor-api approved a plan for a caller outside the approver group"
visitor_message="$(mcp_text)"
grep --quiet "forbidden: ${VISITOR_USER} is not in" <<<"${visitor_message}" ||
  fail "floor-api did not refuse ${VISITOR_USER} with a forbidden error"
echo "floor-api refused ${VISITOR_USER}: ${visitor_message}"

echo "approving ${planner_name} plan ${planner_plan} through floor-api"
mcp_ok approve "$(jq --null-input --compact-output --arg name "${planner_name}" --arg plan "${planner_plan}" \
  '{name: $name, planId: $plan}')"

git_repository_field() {
  kubectl get gitrepository fixture --namespace="${FIXTURE_NAMESPACE}" \
    --output=jsonpath="$1" 2>/dev/null || true
}

[ "$(git_repository_field '{.spec.ref.branch}')" = "${branch}" ] ||
  fail "the fixture GitRepository was not repointed at ${branch}"
[ "$(git_repository_field '{.metadata.annotations.floor\.osinfra\.io/pull-request}')" = "${pull_request}" ] ||
  fail "the fixture GitRepository does not record pull request ${pull_request}"

wait_for is_applied regional-sandbox "regional-sandbox to apply the pull request head"

grep --fixed-strings --quiet "${head_sha:0:10}" \
  <<<"$(terraform_field regional-sandbox '{.status.lastAppliedRevision}')" ||
  fail "regional-sandbox did not apply the pull request head revision ${head_sha}"

[ "$(kubectl get configmap regional --namespace=floor-fixture \
  --output=jsonpath='{.data.workspace}')" = "${branch}" ] ||
  fail "the floor-fixture/regional ConfigMap does not carry the pull request change"

kubectl get events --namespace="${FIXTURE_NAMESPACE}" \
  --field-selector="involvedObject.name=regional-sandbox,reason=Approved" \
  --output=jsonpath='{.items[*].message}' | grep --quiet "${VERIFY_USER}" ||
  fail "floor-api did not record an Approved event on regional-sandbox"

pull_request_comments | grep --quiet "${VERIFY_USER}" ||
  fail "floor-api did not comment the approval on pull request ${pull_request}"

# The fixture repository requires a review, which no local identity can give.
gh pr merge "${pull_request}" --repo="${FIXTURE_REPO}" --squash --delete-branch --admin ||
  fail "could not merge pull request ${pull_request}"

trap - EXIT

merged_sha="$(gh api "repos/${FIXTURE_REPO}/git/ref/heads/main" --jq '.object.sha')" ||
  fail "could not read the merged main revision of ${FIXTURE_REPO}"
MERGED_REVISION="main@sha1:${merged_sha}"
readonly MERGED_REVISION
echo "main merged at ${merged_sha}"

merge_deadline=$((SECONDS + MERGE_WAIT_SECONDS))
while [ "$(git_repository_field '{.spec.ref.branch}')" != "main" ] ||
  [ "$(git_repository_field '{.status.artifact.revision}')" != "${MERGED_REVISION}" ]; do
  [ "${SECONDS}" -lt "${merge_deadline}" ] ||
    fail "the fixture GitRepository did not return to main at ${merged_sha} after the merge"
  echo "waiting for the sandbox to return to main at ${merged_sha} ..."
  sleep "${POLL_SECONDS}"
done

# The stack is left applied at main so a second run starts from the same state.
for terraform_name in main-sandbox regional-sandbox; do
  wait_for settled_at_merged_main "${terraform_name}" "${terraform_name} to settle at main ${merged_sha}"

  if has_pending_plan "${terraform_name}"; then
    approve_pending_plan "${terraform_name}"
    wait_for is_applied "${terraform_name}" "${terraform_name} to apply main"
  fi
done

echo "floor local verification passed"
