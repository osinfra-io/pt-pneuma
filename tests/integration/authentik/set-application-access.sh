#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"

if [ "$#" -ne 1 ] || { [ "$1" != "revoke" ] && [ "$1" != "restore" ]; }; then
  echo "Usage: bash tests/integration/authentik/set-application-access.sh revoke|restore" >&2
  exit 1
fi

revoke=false
if [ "$1" = "revoke" ]; then
  revoke=true
fi

require_local_cluster
start_admin_forward
apply_local_config "-var=revoke_application_access=${revoke}"
