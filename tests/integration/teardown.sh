#!/usr/bin/env bash

# Tears down owned fixtures in reverse dependency order. This deletes local
# users, memberships, and database data.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

for component in openbao agentgateway authentik istio; do
  "${SCRIPT_DIR}/${component}/teardown.sh"
done
