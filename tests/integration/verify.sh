#!/usr/bin/env bash

# Verifies the whole local gateway stack. Stops at the first failed stage and
# never tears down the fixtures.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

run_stage() {
  local name="$1"
  shift

  echo "==> Verifying ${name}"
  if ! "$@"; then
    echo "FAILED: ${name} verification. Fixtures were not torn down." >&2
    exit 1
  fi
}

for component in istio authentik agentgateway openbao; do
  run_stage "${component}" "${SCRIPT_DIR}/${component}/verify.sh"
done

run_stage "holistic anonymous HTTP" python3 -B "${SCRIPT_DIR}/verify/verify-http.py"
run_stage "fail-closed, in-mesh admin-denial, and ztunnel mTLS (Authentik is restored afterwards)" \
  python3 -B "${SCRIPT_DIR}/verify/verify-runtime.py"

echo "Automated local integration checks passed. Google browser sign-in and authenticated identity verification remain pending."
