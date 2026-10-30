#!/usr/bin/env bash

set -euo pipefail

readonly LOCAL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORK_DIR="${LOCAL_DIR}/.work"
readonly KUBE_CONTEXT="docker-desktop"

source "${LOCAL_DIR}/../shared/owner.sh"

require_local_cluster() {
  if [ "$(kubectl config current-context)" != "${KUBE_CONTEXT}" ]; then
    echo "Select the dedicated docker-desktop Kind cluster explicitly before running local tests." >&2
    return 1
  fi
  if [ "$(kubectl --context="${KUBE_CONTEXT}" get configmap "${OWNER_CONFIGMAP}" --namespace="${OWNER_NAMESPACE}" --output=jsonpath='{.data.owner}')" != "${OWNER_VALUE}" ]; then
    echo "The gateway-stack prerequisite step must establish exclusive fixture ownership first." >&2
    return 1
  fi
}

local_tofu() {
  local stage="$1"
  shift
  TF_DATA_DIR="${WORK_DIR}/${stage}/providers" tofu -chdir="${LOCAL_DIR}/${stage}" "$@"
}

apply_local_config() {
  local_tofu config apply -input=false -auto-approve \
    -state="${WORK_DIR}/config/terraform.tfstate" \
    -var-file="${LOCAL_DIR}/../../../../../logos/pt-logos/teams/pt-pneuma.tfvars" \
    -var-file="${WORK_DIR}/config/bootstrap.tfvars.json" "$@"
}

start_admin_forward() {
  kubectl --context="${KUBE_CONTEXT}" port-forward --namespace=authentik \
    --address=127.0.0.1 service/authentik-server 19443:443 \
    >"${WORK_DIR}/port-forward.log" 2>&1 &
  readonly FORWARD_PID=$!
  trap 'kill "${FORWARD_PID}" 2>/dev/null || true; wait "${FORWARD_PID}" 2>/dev/null || true' EXIT
  for _ in $(seq 1 30); do
    if ! kill -0 "${FORWARD_PID}" 2>/dev/null; then
      echo "Authentik admin port-forward failed; inspect ${WORK_DIR}/port-forward.log." >&2
      return 1
    fi
    if grep --quiet '^Forwarding from 127.0.0.1:19443 ' "${WORK_DIR}/port-forward.log" &&
      curl --noproxy '*' --fail --insecure --silent --show-error \
      --connect-timeout 2 --max-time 5 https://127.0.0.1:19443/-/health/live/ >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for the loopback Authentik admin endpoint." >&2
  return 1
}
