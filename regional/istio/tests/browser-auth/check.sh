#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$root/check-header-strip.py"
export TF_WORKSPACE=us-east1-b-istio-manifests-sandbox
tofu -chdir="$root" init -backend=false -input=false -no-color
tofu -chdir="$root" test -no-color
