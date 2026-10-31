#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
readonly SCRIPT_DIR TEST_DIR
trap 'rm -f "${TEST_DIR}/openbao/.work/"* "${TEST_DIR}/openbao/"*.sh "${TEST_DIR}/shared/cluster.sh" "${TEST_DIR}/output"; rmdir "${TEST_DIR}/openbao/.work" "${TEST_DIR}/openbao" "${TEST_DIR}/shared" "${TEST_DIR}"' EXIT

mkdir -p "${TEST_DIR}/openbao/.work" "${TEST_DIR}/shared"
cp "${SCRIPT_DIR}/teardown.sh" "${TEST_DIR}/openbao/"
cat >"${TEST_DIR}/openbao/configure.sh" <<'SH'
#!/usr/bin/env bash
echo "Configuration cleanup requires an available API and credentials" >&2
exit 1
SH
cat >"${TEST_DIR}/shared/cluster.sh" <<'SH'
OWNER_VALUE="test-owner"
assert_docker_desktop_kind_cluster() { return 0; }
assert_local_gateway_stack_owner() { [ "${TEST_OWNER:-owned}" = owned ]; }
kubectl() {
  [ "${TEST_KUBECTL:-success}" = success ] || return 1
  [ "$1 $2 $3" = "get namespace openbao" ] || return 1
  [ ! -f "${WORK_DIR}/namespace" ] || echo namespace/openbao
}
tofu_stage() {
  case "$1 $2" in
    *" init") ;;
    "regional state")
      [ "${TEST_TRACKED:-yes}" != yes ] || echo kubernetes_namespace_v1.openbao
      ;;
    "routing destroy") ;;
    "regional destroy")
      [ "${TEST_DESTROY:-success}" = success ] || return 1
      [ ! -f "${WORK_DIR}/config.tfstate" ] || touch "${WORK_DIR}/state-retained"
      rm -f "${WORK_DIR}/namespace"
      ;;
    *) return 1 ;;
  esac
}
SH

readonly WORK_DIR="${TEST_DIR}/openbao/.work"
touch "${WORK_DIR}/config.tfstate" "${WORK_DIR}/config.tfstate.backup" \
  "${WORK_DIR}/regional.tfstate" "${WORK_DIR}/namespace"

if TEST_OWNER=foreign bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1; then
  echo "Teardown must reject a foreign ownership marker" >&2
  exit 1
fi
[ -f "${WORK_DIR}/namespace" ] && [ -f "${WORK_DIR}/config.tfstate" ]

if TEST_KUBECTL=fail bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1; then
  echo "Teardown must retain state when namespace inspection fails" >&2
  exit 1
fi
[ -f "${WORK_DIR}/namespace" ] && [ -f "${WORK_DIR}/config.tfstate" ]

if TEST_TRACKED=no bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1; then
  echo "Teardown must reject a namespace missing from fixture state" >&2
  exit 1
fi
[ -f "${WORK_DIR}/namespace" ] && [ -f "${WORK_DIR}/config.tfstate" ]

if TEST_DESTROY=fail bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1; then
  echo "Teardown must report runtime destruction failure" >&2
  exit 1
fi
[ -f "${WORK_DIR}/config.tfstate" ] && [ -f "${WORK_DIR}/config.tfstate.backup" ]

bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1 || {
  cat "${TEST_DIR}/output" >&2
  exit 1
}
[ -f "${WORK_DIR}/state-retained" ]
[ ! -f "${WORK_DIR}/namespace" ]
[ ! -f "${WORK_DIR}/config.tfstate" ] && [ ! -f "${WORK_DIR}/config.tfstate.backup" ]
bash "${TEST_DIR}/openbao/teardown.sh" >"${TEST_DIR}/output" 2>&1
echo "OpenBao teardown ownership, unavailable API, failure retention, and repeat-reset tests passed."
