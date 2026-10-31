#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$(mktemp -d)"
readonly SCRIPT_DIR TEST_DIR
trap 'rm -f "${TEST_DIR}/output"; rmdir "${TEST_DIR}"' EXIT

kubectl() {
  [ "$*" = 'patch --local --filename=- --type=merge --patch={"metadata":{"annotations":{"helm.sh/resource-policy":"keep"}}} --output=json' ] || return 1
  cat >/dev/null
  printf '%s' "${MOCK_OUTPUT}"
  return "${MOCK_STATUS:-0}"
}
export -f kubectl

export MOCK_OUTPUT='{"kind":"CustomResourceDefinition","metadata":{"name":"first.example.invalid","annotations":{"helm.sh/resource-policy":"keep"}}}
{"kind":"CustomResourceDefinition","metadata":{"name":"second.example.invalid","annotations":{"helm.sh/resource-policy":"keep"}}}'
bash "${SCRIPT_DIR}/retain-crds.sh" </dev/null >"${TEST_DIR}/output"
[ "$(grep -c '^---$' "${TEST_DIR}/output")" = 2 ]
grep -v '^---$' "${TEST_DIR}/output" |
  jq --slurp --exit-status 'length == 2 and all(.[]; .metadata.annotations["helm.sh/resource-policy"] == "keep")' >/dev/null

invalid_outputs=('{"kind":"Deployment"}' '' 'invalid json')
for invalid_output in "${invalid_outputs[@]}"; do
  export MOCK_OUTPUT="${invalid_output}"
  if bash "${SCRIPT_DIR}/retain-crds.sh" </dev/null >"${TEST_DIR}/output" 2>/dev/null; then
    echo "Expected invalid renderer output to fail" >&2
    exit 1
  fi
  [ ! -s "${TEST_DIR}/output" ]
done

export MOCK_OUTPUT='{"kind":"CustomResourceDefinition"}'
export MOCK_STATUS=1
if bash "${SCRIPT_DIR}/retain-crds.sh" </dev/null >/dev/null 2>&1; then
  echo "Expected kubectl failure to propagate" >&2
  exit 1
fi
echo "CRD post-renderer tests passed."
