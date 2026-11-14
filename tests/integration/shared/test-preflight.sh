#!/usr/bin/env bash

set -euo pipefail

SHARED_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
INTEGRATION_DIR="${TEST_DIR}/integration"
readonly SHARED_DIR TEST_DIR INTEGRATION_DIR
trap 'rm -rf -- "${TEST_DIR}"' EXIT

mkdir -p "${INTEGRATION_DIR}/shared" "${TEST_DIR}/bin"
cp "${SHARED_DIR}/preflight.sh" "${INTEGRATION_DIR}/shared/"
cp "${SHARED_DIR}/owner.sh" "${INTEGRATION_DIR}/shared/"
for tool in curl jq openssl python3 tofu; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"${TEST_DIR}/bin/${tool}"
  chmod +x "${TEST_DIR}/bin/${tool}"
done
export PATH="${TEST_DIR}/bin:${PATH}"
export OWNER_PRESENT=no
export MOCK_OWNER="osinfra-local-gateway-stack"
export EXTRA_NAMESPACE=""
export EXTRA_WORKLOAD=""
export HELM_RELEASE=""
export EXISTING_CRDS=""
export CLAIM_FILE="${TEST_DIR}/claimed"

docker() {
  case "$1" in
    info) ;;
    inspect) echo desktop ;;
    exec) echo shared ;;
    *) return 1 ;;
  esac
}

kubectl() {
  case "$*" in
    "config current-context") echo docker-desktop ;;
    *"get --raw=/readyz") ;;
    *"get nodes "*) echo desktop-control-plane ;;
    *"get configmap "*)
      [ "${OWNER_PRESENT}" = yes ] || return 1
      echo "${MOCK_OWNER}"
      ;;
    *"get namespaces "*) echo "default kube-system kube-public kube-node-lease local-path-storage ${EXTRA_NAMESPACE}" ;;
    *"get pods,deployments,replicasets,statefulsets,daemonsets,jobs,cronjobs "*)
      [ -z "${EXTRA_WORKLOAD}" ] || echo "${EXTRA_WORKLOAD}"
      ;;
    *"get crds "*) echo "${EXISTING_CRDS}" ;;
    *"create configmap "*) touch "${CLAIM_FILE}" ;;
    *) return 1 ;;
  esac
}

helm() {
  [ "$*" = "--kube-context=docker-desktop list --all-namespaces --short --deployed --failed --pending --uninstalling" ] || return 1
  [ -z "${HELM_RELEASE}" ] || echo "${HELM_RELEASE}"
}
export -f docker kubectl helm

create_workdirs() {
  for component in istio authentik agentgateway agent-substrate kagent openbao; do
    mkdir -p "${INTEGRATION_DIR}/${component}/.work"
    : >"${INTEGRATION_DIR}/${component}/.work/state"
  done
}

assert_workdirs_exist() {
  for component in istio authentik agentgateway agent-substrate kagent openbao; do
    [ -f "${INTEGRATION_DIR}/${component}/.work/state" ]
  done
}

assert_workdirs_removed() {
  for component in istio authentik agentgateway agent-substrate kagent openbao; do
    [ ! -e "${INTEGRATION_DIR}/${component}/.work" ]
  done
}

expect_preflight_failure() {
  local expected="$1"
  if bash "${INTEGRATION_DIR}/shared/preflight.sh" >"${TEST_DIR}/output" 2>&1; then
    echo "Expected preflight to fail: ${expected}" >&2
    exit 1
  fi
  grep -Fq "${expected}" "${TEST_DIR}/output"
  [ ! -e "${CLAIM_FILE}" ]
  assert_workdirs_exist
}

create_workdirs
export HELM_RELEASE=active-release
expect_preflight_failure "Existing Helm installations prevent setup on this unowned cluster."

export HELM_RELEASE=""
export EXTRA_NAMESPACE=existing-app
expect_preflight_failure "Existing namespace existing-app has no fixture ownership record"

export EXTRA_NAMESPACE=""
export EXTRA_WORKLOAD=deployment.apps/manual-app
expect_preflight_failure "Existing workloads in the default namespace prevent setup on this unowned cluster."

export EXTRA_WORKLOAD=""
export EXISTING_CRDS=gateways.gateway.networking.k8s.io
expect_preflight_failure "Existing gateway/mesh CRDs prevent setup on this unowned cluster"

export EXISTING_CRDS=""
bash "${INTEGRATION_DIR}/shared/preflight.sh" >"${TEST_DIR}/output" 2>&1
[ -f "${CLAIM_FILE}" ]
assert_workdirs_removed

create_workdirs
export OWNER_PRESENT=yes
bash "${INTEGRATION_DIR}/shared/preflight.sh" >"${TEST_DIR}/output" 2>&1
assert_workdirs_exist

export MOCK_OWNER=another-owner
if bash "${INTEGRATION_DIR}/shared/preflight.sh" >"${TEST_DIR}/output" 2>&1; then
  echo "Expected foreign ownership marker to prevent setup" >&2
  exit 1
fi
grep -Fq "The cluster ownership marker belongs to another owner." "${TEST_DIR}/output"
assert_workdirs_exist

echo "Preflight empty-cluster cleanup and ownership tests passed."
