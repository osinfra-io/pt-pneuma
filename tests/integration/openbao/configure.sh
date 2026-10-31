#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly AUTHENTIK_DIR="${SCRIPT_DIR}/../authentik"
readonly AUTHENTIK_STATE="${AUTHENTIK_DIR}/.work/config/terraform.tfstate"
readonly AUTHENTIK_CONFIG="${AUTHENTIK_DIR}/config"
readonly AUTHENTIK_CA_FILE="${SCRIPT_DIR}/../istio/.work/gateway-localhost.crt"
readonly INIT_FILE="${WORK_DIR}/openbao-init.json"
readonly API_PORT="18200"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "OpenBao local configuration: $*" >&2
  exit 1
}

stop_port_forward() {
  if [ -n "${PORT_FORWARD_PID:-}" ]; then
    kill "${PORT_FORWARD_PID}" 2>/dev/null || true
    wait "${PORT_FORWARD_PID}" 2>/dev/null || true
  fi
}

authentik_output() {
  TF_DATA_DIR="${AUTHENTIK_DIR}/.work/config/providers" \
    tofu -chdir="${AUTHENTIK_CONFIG}" output \
    -state="${AUTHENTIK_STATE}" -raw "$1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' was not found"
}

readonly ACTION="${1:-apply}"
case "${ACTION}" in
  apply | destroy) ;;
  *) fail "usage: configure.sh [apply|destroy]" ;;
esac

require_command jq
require_command curl
require_command kubectl
require_command tofu
assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner || fail "initialize the dedicated local gateway stack through preflight first"
[ -s "${INIT_FILE}" ] || fail "OpenBao initialization credentials are missing; run setup.sh first"
[ -s "${AUTHENTIK_STATE}" ] || fail "local Authentik config state is missing; run tests/integration/authentik/setup.sh first"
[ -s "${AUTHENTIK_CA_FILE}" ] || fail "local gateway certificate is missing; run tests/integration/istio/setup.sh first"

umask 077
root_token="$(jq -er '.root_token | strings | select(length > 0)' "${INIT_FILE}")"
authentik_discovery_ca_pem="$(cat "${AUTHENTIK_CA_FILE}")"
authentik_client_id="$(authentik_output openbao_client_id)"
authentik_client_secret="$(authentik_output openbao_client_secret)"
authentik_issuer_url="$(authentik_output openbao_issuer_url)"

[ -n "${authentik_client_id}" ] || fail "local Authentik did not output an OpenBao client ID"
[ -n "${authentik_client_secret}" ] || fail "local Authentik did not output an OpenBao client secret"
[ -n "${authentik_issuer_url}" ] || fail "local Authentik did not output an OpenBao issuer URL"

tofu_stage config init \
  -reconfigure \
  -backend-config="path=${WORK_DIR}/config.tfstate" \
  -input=false

kubectl wait --namespace=openbao pod/openbao-0 \
  --for=condition=Ready --timeout=180s
trap stop_port_forward EXIT
command kubectl --context=docker-desktop --namespace=openbao \
  port-forward pod/openbao-0 "${API_PORT}:8200" \
  >"${WORK_DIR}/config-port-forward.log" 2>&1 &
PORT_FORWARD_PID=$!

api_ready=false
for _ in $(seq 1 30); do
  if ! kill -0 "${PORT_FORWARD_PID}" 2>/dev/null; then
    fail "OpenBao API port-forward stopped; see ${WORK_DIR}/config-port-forward.log"
  fi
  if curl --noproxy '*' --connect-timeout 2 --max-time 3 --silent --show-error \
    --output /dev/null "http://127.0.0.1:${API_PORT}/v1/sys/health" \
    2>"${WORK_DIR}/config-port-forward-health.log"; then
    api_ready=true
    break
  fi
  sleep 1
done
[ "${api_ready}" = true ] ||
  fail "OpenBao API port-forward did not become ready; see ${WORK_DIR}/config-port-forward-health.log"

export TF_VAR_authentik_client_id="${authentik_client_id}"
export TF_VAR_authentik_client_secret="${authentik_client_secret}"
export TF_VAR_authentik_discovery_ca_pem="${authentik_discovery_ca_pem}"
export TF_VAR_authentik_issuer_url="${authentik_issuer_url}"
export TF_VAR_openbao_address="http://127.0.0.1:${API_PORT}"
export TF_VAR_openbao_root_token="${root_token}"

if [ "${ACTION}" = "apply" ]; then
  tofu_stage config apply -auto-approve -input=false
else
  tofu_stage config destroy -auto-approve -input=false
fi
