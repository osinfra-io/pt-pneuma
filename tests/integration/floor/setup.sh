#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
readonly FIXTURE_NAMESPACE="pt-techne-floor-fixture"
readonly PASSPHRASE_FILE="${WORK_DIR}/state-passphrase"
readonly TOKEN_FILE="${WORK_DIR}/github-token"
source "${SCRIPT_DIR}/../shared/cluster.sh"

# Consumed by the floor configuration stage that reconciles the floor objects.
FLOOR_CONFIG_REPO="${FLOOR_CONFIG_REPO:-https://github.com/osinfra-io/pt-techne-floor}"
FLOOR_CONFIG_REF="${FLOOR_CONFIG_REF:-main}"
export FLOOR_CONFIG_REPO FLOOR_CONFIG_REF

fail() {
  echo "floor local setup: $*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "required command '$1' was not found"
}

for command_name in docker kubectl helm tofu gh openssl; do
  require_command "${command_name}"
done

docker info >/dev/null 2>&1 || fail "Docker daemon is not available"
assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "initialize the dedicated local gateway stack through preflight before setup"

if helm status flux-operator --namespace=flux-system >/dev/null 2>&1 &&
  ! tofu_stage engine state list 2>/dev/null |
    grep --fixed-strings --line-regexp --quiet 'helm_release.flux_operator'; then
  fail "Helm release 'flux-operator' exists but is not in engine state; explicitly import/adopt it before setup"
fi

mkdir -p "${WORK_DIR}"

# The Branch Planner authenticates to GitHub as the signed-in user.
if ! (
  umask 077
  gh auth token >"${TOKEN_FILE}"
) || [ ! -s "${TOKEN_FILE}" ]; then
  rm -f "${TOKEN_FILE}"
  fail "no GitHub token is available; run 'gh auth login' with access to osinfra-io/pt-techne-floor-fixture"
fi

if [ ! -s "${PASSPHRASE_FILE}" ]; then
  (
    umask 077
    openssl rand -base64 32 >"${PASSPHRASE_FILE}"
  )
fi

kubectl create namespace "${FIXTURE_NAMESPACE}" --dry-run=client --output=yaml |
  kubectl apply --filename=- >/dev/null

# Runners encrypt fixture state with a locally generated passphrase; the HCL never leaves .work.
encryption_file="${WORK_DIR}/runner-encryption.hcl"
(
  umask 077
  cat >"${encryption_file}" <<HCL
key_provider "pbkdf2" "default" {
  passphrase = "$(cat "${PASSPHRASE_FILE}")"
}
method "aes_gcm" "default" {
  keys = key_provider.pbkdf2.default
}
state {
  method   = method.aes_gcm.default
  enforced = true
}
HCL
)
trap 'rm -f -- "${encryption_file}"' EXIT

kubectl create secret generic floor-runner-env \
  --namespace="${FIXTURE_NAMESPACE}" \
  --from-file="TF_ENCRYPTION=${encryption_file}" \
  --dry-run=client --output=yaml |
  kubectl apply --filename=- >/dev/null ||
  fail "could not create the floor runner environment secret"

rm -f -- "${encryption_file}"
trap - EXIT

tofu_stage engine init -reconfigure -backend-config="path=${WORK_DIR}/engine.tfstate" -input=false
# The FluxInstance manifest needs its CRD at plan time, so install the Flux Operator chart first.
tofu_stage engine apply -auto-approve -input=false -target=helm_release.flux_operator

# The Branch Planner reads pull requests and writes plan comments with this token.
kubectl create secret generic branch-planner-token \
  --namespace=flux-system \
  --from-file="token=${TOKEN_FILE}" \
  --dry-run=client --output=yaml |
  kubectl apply --filename=- >/dev/null ||
  fail "could not create the branch-planner token secret"

tofu_stage engine apply -auto-approve -input=false

echo "The floor configuration stage uses FLOOR_CONFIG_REPO=${FLOOR_CONFIG_REPO} at FLOOR_CONFIG_REF=${FLOOR_CONFIG_REF}."

# Flux reconciles the floor configuration; the Terraform objects are not health-checkable,
# so the Kustomization does not wait on them.
if ! kubectl apply --filename=- >/dev/null <<YAML
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: pt-techne-floor
  namespace: flux-system
spec:
  interval: 1m
  ref:
    branch: ${FLOOR_CONFIG_REF}
  url: ${FLOOR_CONFIG_REPO}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: floor-local
  namespace: flux-system
spec:
  interval: 1m
  path: ./floors/local
  prune: true
  sourceRef:
    kind: GitRepository
    name: pt-techne-floor
  wait: false
YAML
then
  fail "could not apply the floor configuration source and kustomization"
fi

"${SCRIPT_DIR}/verify.sh"
