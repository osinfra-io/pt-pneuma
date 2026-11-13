#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly WORK_DIR="${SCRIPT_DIR}/.work"
readonly OWNER_NAME="local-gateway-stack-owner"
source "${SCRIPT_DIR}/../shared/cluster.sh"

fail() {
  echo "Agent Substrate local setup: $*" >&2
  exit 1
}

for command_name in docker kubectl helm tofu; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "required command '${command_name}' was not found"
done

docker info >/dev/null 2>&1 || fail "Docker daemon is not available"
assert_docker_desktop_kind_cluster || fail "Kubernetes is not backed by the Docker Desktop Kind cluster"
assert_local_gateway_stack_owner "${OWNER_NAME}" kube-system "${OWNER_VALUE}" ||
  fail "initialize the dedicated local gateway stack through preflight before setup"

readonly SUBSTRATE_VERSION="1.0.1"
readonly SUBSTRATE_SOURCE_DIR="${WORK_DIR}/substrate-src"
readonly PODCERT_NAMESPACE="podcertificate-controller-system"
readonly PODCERT_OWNER_LABEL="local-fixture.osinfra.io/owner=agent-substrate"

# The substrate chart needs the ClusterTrustBundle, ClusterTrustBundleProjection and
# PodCertificateRequest feature gates plus certificates.k8s.io/v1beta1; the fixture
# checks for them rather than reconfiguring the cluster.
kubectl api-versions | grep --fixed-strings --line-regexp --quiet certificates.k8s.io/v1beta1 ||
  fail "certificates.k8s.io/v1beta1 is not served; enable the ClusterTrustBundle, ClusterTrustBundleProjection and PodCertificateRequest feature gates"

command -v go >/dev/null 2>&1 || fail "required command 'go' was not found (used to run the upstream ate-setup CA tool)"

mkdir -p "${WORK_DIR}"
if [ ! -d "${SUBSTRATE_SOURCE_DIR}" ]; then
  git clone --quiet --depth 1 --branch "v${SUBSTRATE_VERSION}" \
    https://github.com/kagent-dev/substrate "${SUBSTRATE_SOURCE_DIR}"
fi

# Claim the certificate controller namespace for this fixture and refuse one that already exists unowned.
if kubectl get namespace "${PODCERT_NAMESPACE}" >/dev/null 2>&1; then
  owned_namespaces="$(kubectl get namespace --selector="${PODCERT_OWNER_LABEL}" --output=name)"
  grep --fixed-strings --line-regexp --quiet "namespace/${PODCERT_NAMESPACE}" <<<"${owned_namespaces}" ||
    fail "namespace '${PODCERT_NAMESPACE}' exists but is not owned by this fixture; remove or adopt it explicitly before setup"
else
  kubectl create namespace "${PODCERT_NAMESPACE}"
  kubectl label namespace "${PODCERT_NAMESPACE}" "${PODCERT_OWNER_LABEL}"
fi

# Install the cluster-wide certificate controller and its CA pools once.
if ! kubectl get secret postgres-ca-pool --namespace="${PODCERT_NAMESPACE}" >/dev/null 2>&1; then
  (cd "${SUBSTRATE_SOURCE_DIR}" && go run ./cmd/ate-setup --context=docker-desktop create podcertificate-controller-cas)
fi
helm upgrade --install substrate-podcert oci://ghcr.io/kagent-dev/substrate/helm/substrate-podcert \
  --version "${SUBSTRATE_VERSION}" --kube-context=docker-desktop \
  --namespace="${PODCERT_NAMESPACE}" --wait --timeout=5m

if helm status substrate --namespace=ate-system >/dev/null 2>&1 &&
  ! tofu_stage regional state list 2>/dev/null |
    grep --fixed-strings --quiet 'module.agent_substrate.helm_release.substrate'; then
  fail "Helm release 'substrate' exists but is not in regional state; explicitly import/adopt it before setup"
fi

tofu_stage regional init -reconfigure -backend-config="path=${WORK_DIR}/regional.tfstate" -input=false

# The API server needs its roles and schema before it starts, so prepare PostgreSQL first.
tofu_stage regional apply -auto-approve -input=false -target=kubernetes_stateful_set_v1.postgresql
kubectl rollout status statefulset/postgresql --namespace=ate-system --timeout=180s
kubectl exec --namespace=ate-system --stdin postgresql-0 -- \
  psql --no-psqlrc --set=ON_ERROR_STOP=1 --single-transaction --username=postgres --dbname=substrate \
  --set=substrate_schema=substrate \
  --set=substrate_owner_role=substrate_owner \
  --set=substrate_owner_user=substrate_owner_user \
  --set=substrate_owner_password=local-fixture \
  --set=substrate_readwrite_role=substrate_readwrite \
  --set=substrate_readwrite_user=substrate_readwrite_user \
  --set=substrate_readwrite_password=local-fixture \
  <"${SUBSTRATE_SOURCE_DIR}/pkg/postgressetup/setup.sql"

# Signing material the chart expects to exist: actor JWT pool, actor identity CA, and egress MITM CA.
for secret_command in jwt-authority-pool:actor-id-jwt-pool actor-id-ca-pool:actor-id-ca-pool \
  actor-id-ca-certs:actor-id-ca-certs egress-mitm-ca-pool:egress-mitm-ca-pool; do
  if ! kubectl get secret "${secret_command#*:}" --namespace=ate-system >/dev/null 2>&1; then
    (cd "${SUBSTRATE_SOURCE_DIR}" && go run ./cmd/ate-setup --context=docker-desktop create "${secret_command%%:*}")
  fi
done

# The chart mounts this ConfigMap but does not create it.
if ! kubectl get configmap ate-api-authentication --namespace=ate-system >/dev/null 2>&1; then
  (cd "${SUBSTRATE_SOURCE_DIR}" && go run ./cmd/ate-setup --context=docker-desktop create api-authentication-config)
fi

tofu_stage regional apply -auto-approve -input=false

"${SCRIPT_DIR}/verify.sh"
