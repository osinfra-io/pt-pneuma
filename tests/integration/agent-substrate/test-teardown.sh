#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
readonly SCRIPT_DIR TEST_DIR
trap 'rm -f "${TEST_DIR}/agent-substrate/teardown.sh" "${TEST_DIR}/shared/cluster.sh" "${TEST_DIR}/output" "${TEST_DIR}/actions"; rmdir "${TEST_DIR}/agent-substrate" "${TEST_DIR}/shared" "${TEST_DIR}"' EXIT

mkdir -p "${TEST_DIR}/agent-substrate" "${TEST_DIR}/shared"
cp "${SCRIPT_DIR}/teardown.sh" "${TEST_DIR}/agent-substrate/"
cat >"${TEST_DIR}/shared/cluster.sh" <<'SH'
OWNER_VALUE="test-owner"
assert_docker_desktop_kind_cluster() { return 0; }
assert_local_gateway_stack_owner() { return 0; }
kubectl() {
  case "$1 $2" in
    "get namespace")
      [ "$#" -eq 4 ] && [ "$3" = "--selector=local-fixture.osinfra.io/owner=agent-substrate" ] &&
        [ "$4" = "--output=name" ] || return 1
      [ "${TEST_OWNER}" != error ] || return 1
      case "${TEST_OWNER}" in
        owned) echo namespace/podcertificate-controller-system ;;
        other) echo namespace/other ;;
      esac
      ;;
    "delete namespace") echo delete >>"${TEST_DIR}/actions" ;;
    *) return 1 ;;
  esac
}
helm() { echo uninstall >>"${TEST_DIR}/actions"; }
SH

export TEST_DIR
for TEST_OWNER in absent other error owned; do
  export TEST_OWNER
  rm -f "${TEST_DIR}/actions"
  if bash "${TEST_DIR}/agent-substrate/teardown.sh" >"${TEST_DIR}/output" 2>&1; then
    [ "${TEST_OWNER}" != error ] || { echo "Inspection failure was ignored" >&2; exit 1; }
  else
    [ "${TEST_OWNER}" = error ] || { cat "${TEST_DIR}/output" >&2; exit 1; }
  fi
  if [ "${TEST_OWNER}" = owned ]; then
    [ "$(cat "${TEST_DIR}/actions")" = "$(printf 'uninstall\ndelete')" ]
  else
    [ ! -f "${TEST_DIR}/actions" ]
  fi
done
echo "Agent Substrate teardown ownership tests passed."
