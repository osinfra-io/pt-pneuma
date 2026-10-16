#!/usr/bin/env bash

# Sets up the whole local gateway stack on Docker Desktop Kind.
# Pass --claim on a fresh, dedicated cluster to record fixture ownership first.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

"${SCRIPT_DIR}/shared/preflight.sh" "$@"

# Kubernetes manifest providers need CRDs at plan time, so each component is a separate stage.
"${SCRIPT_DIR}/istio/setup.sh"
"${SCRIPT_DIR}/authentik/setup.sh"
"${SCRIPT_DIR}/istio/apply-auth.sh"
"${SCRIPT_DIR}/istio/apply-routes.sh"
"${SCRIPT_DIR}/agentgateway/setup.sh"
"${SCRIPT_DIR}/openbao/setup.sh"

echo "Local gateway stack is ready. Run tests/integration/verify.sh, then complete Google sign-in manually."
