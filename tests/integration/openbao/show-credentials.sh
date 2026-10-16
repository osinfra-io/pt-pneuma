#!/usr/bin/env bash

# Prints the local OpenBao URL and root token. The token is a throwaway for the
# local development cluster only; never reuse it anywhere else.

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INIT_FILE="${SCRIPT_DIR}/.work/openbao-init.json"

[ -f "${INIT_FILE}" ] || {
  echo "OpenBao credentials: ${INIT_FILE} not found; run tests/integration/openbao/setup.sh first" >&2
  exit 1
}

echo "OpenBao UI:  https://openbao.localhost/ui/"
echo "Method:      Token"
echo "Root token:  $(jq --raw-output '.root_token' "${INIT_FILE}")"
