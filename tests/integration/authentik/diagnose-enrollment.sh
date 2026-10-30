#!/usr/bin/env bash

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/shared.sh"
require_local_cluster
start_admin_forward
python3 -B "${LOCAL_DIR}/diagnose-enrollment.py" "${WORK_DIR}"
