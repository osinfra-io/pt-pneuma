#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

if [ "${1:-}" != "--enable" ] || [ "$#" -ne 1 ]; then
  echo "Usage: bash tests/integration/agent-substrate/enable-feature-gates.sh --enable" >&2
  exit 1
fi

assert_docker_desktop_kind_cluster
assert_local_gateway_stack_owner
version="$(kubectl version --output=json | jq -r '.serverVersion.gitVersion')"
case "${version}" in
  v1.36.*) ;;
  *) echo "Unsupported Kubernetes version ${version}; review feature gates before editing the node." >&2; exit 1 ;;
esac
nodes="$(kubectl get nodes --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
if [ "$(printf '%s\n' "${nodes}" | wc -l)" -ne 1 ]; then
  echo "Feature-gate setup supports only a single-node dedicated cluster." >&2
  exit 1
fi
node="${nodes}"
umask 077
mkdir -p "${SCRIPT_DIR}/.work"
backup="$(mktemp -d "${SCRIPT_DIR}/.work/feature-gate-backup.XXXXXXXX")"
docker cp "${node}:/etc/kubernetes/manifests/kube-apiserver.yaml" "${backup}/apiserver.yaml"
docker cp "${node}:/var/lib/kubelet/config.yaml" "${backup}/kubelet.yaml"
echo "Node configuration backups: ${backup}"
python3 "${SCRIPT_DIR}/feature_gate_config.py" \
  "${backup}/apiserver.yaml" "${backup}/kubelet.yaml" \
  "${backup}/apiserver-updated.yaml" "${backup}/kubelet-updated.yaml"

if cmp -s "${backup}/apiserver.yaml" "${backup}/apiserver-updated.yaml" &&
  cmp -s "${backup}/kubelet.yaml" "${backup}/kubelet-updated.yaml"; then
  echo "Feature gates are already configured; run Agent Substrate setup to verify the API."
  exit 0
fi

node_tmp="$(docker exec "${node}" mktemp -d /tmp/local-feature-gates.XXXXXXXX)"
modified=false
complete=false

# These functions run indirectly from the EXIT trap.
# shellcheck disable=SC2329
wait_api() {
  for _ in $(seq 1 60); do
    if kubectl --request-timeout=5s get --raw=/readyz >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  return 1
}

# shellcheck disable=SC2329
restore() {
  docker exec --interactive "${node}" sh -c 'cat > "$1"' sh "${node_tmp}/apiserver.yaml" <"${backup}/apiserver.yaml" &&
    docker exec --interactive "${node}" sh -c 'cat > "$1"' sh "${node_tmp}/kubelet.yaml" <"${backup}/kubelet.yaml" &&
    docker exec "${node}" sh -c '
      install -m 600 "$1/apiserver.yaml" /etc/kubernetes/.local-apiserver-restore.yaml &&
      install -m 600 "$1/kubelet.yaml" /var/lib/kubelet/.local-kubelet-restore.yaml &&
      mv /etc/kubernetes/.local-apiserver-restore.yaml /etc/kubernetes/manifests/kube-apiserver.yaml &&
      mv /var/lib/kubelet/.local-kubelet-restore.yaml /var/lib/kubelet/config.yaml &&
      systemctl restart kubelet
    ' sh "${node_tmp}" &&
    wait_api
}

# shellcheck disable=SC2329
cleanup() {
  if [ "${modified}" = true ] && [ "${complete}" = false ]; then
    if restore; then
      echo "Feature-gate setup failed; original node configuration was restored. Backups: ${backup}" >&2
    else
      echo "Feature-gate setup failed and automatic restoration failed; inspect node immediately. Backups: ${backup}" >&2
    fi
  fi
  docker exec "${node}" sh -c 'rm -f "$1/apiserver.yaml" "$1/kubelet.yaml"; rmdir "$1"' sh "${node_tmp}" ||
    echo "Could not remove temporary node files at ${node_tmp}." >&2
}
trap cleanup EXIT

docker exec --interactive "${node}" sh -c 'cat > "$1"' sh "${node_tmp}/apiserver.yaml" <"${backup}/apiserver-updated.yaml"
docker exec --interactive "${node}" sh -c 'cat > "$1"' sh "${node_tmp}/kubelet.yaml" <"${backup}/kubelet-updated.yaml"
modified=true
docker exec "${node}" sh -c '
  install -m 600 "$1/apiserver.yaml" /etc/kubernetes/.local-apiserver-update.yaml &&
  install -m 600 "$1/kubelet.yaml" /var/lib/kubelet/.local-kubelet-update.yaml &&
  mv /var/lib/kubelet/.local-kubelet-update.yaml /var/lib/kubelet/config.yaml &&
  systemctl restart kubelet &&
  systemctl is-active --quiet kubelet &&
  mv /etc/kubernetes/.local-apiserver-update.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
' sh "${node_tmp}"

for _ in $(seq 1 60); do
  if kubectl --request-timeout=5s get --raw=/apis/certificates.k8s.io/v1beta1 2>/dev/null |
    jq -e '[.resources[].name] | index("podcertificaterequests") != null and index("clustertrustbundles") != null' >/dev/null &&
    kubectl --request-timeout=5s get --raw="/api/v1/nodes/${node}/proxy/configz" 2>/dev/null |
    jq -e '.kubeletconfig.featureGates | .ClusterTrustBundle == true and .ClusterTrustBundleProjection == true and .PodCertificateRequest == true' >/dev/null &&
    kubectl wait --for=condition=Ready "node/${node}" --timeout=15s >/dev/null 2>&1; then
    complete=true
    echo "Certificate APIs and kubelet feature gates are ready."
    exit 0
  fi
  sleep 3
done
echo "Timed out waiting for the certificate API and kubelet feature gates." >&2
exit 1
