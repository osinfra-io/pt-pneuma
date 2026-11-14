#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

if [ "$#" -ne 0 ]; then
  echo "Usage: enable-feature-gates.sh" >&2
  exit 1
fi

assert_docker_desktop_kind_cluster
assert_local_gateway_stack_owner
nodes="$(kubectl get nodes --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
if [ "$(printf '%s\n' "${nodes}" | wc -l)" -ne 1 ]; then
  echo "Feature-gate setup supports only a single-node dedicated cluster." >&2
  exit 1
fi
node="${nodes}"

umask 077
mkdir -p "${SCRIPT_DIR}/.work"
working_dir="$(mktemp -d "${SCRIPT_DIR}/.work/feature-gates.XXXXXXXX")"
trap 'rm -rf -- "${working_dir}"' EXIT
docker cp "${node}:/etc/kubernetes/manifests/kube-apiserver.yaml" "${working_dir}/apiserver.yaml"
docker cp "${node}:/var/lib/kubelet/config.yaml" "${working_dir}/kubelet.yaml"
python3 "${SCRIPT_DIR}/feature_gate_config.py" \
  "${working_dir}/apiserver.yaml" "${working_dir}/kubelet.yaml" \
  "${working_dir}/apiserver-updated.yaml" "${working_dir}/kubelet-updated.yaml"

wait_features() {
  for _ in $(seq 1 60); do
    if kubectl --request-timeout=5s get --raw=/apis/certificates.k8s.io/v1beta1 2>/dev/null |
      jq -e '[.resources[].name] | index("podcertificaterequests") != null and index("clustertrustbundles") != null' >/dev/null &&
      kubectl --request-timeout=5s get --raw="/api/v1/nodes/${node}/proxy/configz" 2>/dev/null |
      jq -e '.kubeletconfig.featureGates | .ClusterTrustBundle == true and .ClusterTrustBundleProjection == true and .PodCertificateRequest == true' >/dev/null &&
      kubectl wait --for=condition=Ready "node/${node}" --timeout=15s >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
  done
  echo "Timed out waiting for the certificate API and kubelet feature gates." >&2
  return 1
}

if cmp -s "${working_dir}/apiserver.yaml" "${working_dir}/apiserver-updated.yaml" &&
  cmp -s "${working_dir}/kubelet.yaml" "${working_dir}/kubelet-updated.yaml"; then
  wait_features
  echo "Certificate APIs and kubelet feature gates are ready."
  exit 0
fi

node_tmp="$(docker exec "${node}" mktemp -d /tmp/local-feature-gates.XXXXXXXX)"
docker cp "${working_dir}/apiserver-updated.yaml" "${node}:${node_tmp}/apiserver.yaml"
docker cp "${working_dir}/kubelet-updated.yaml" "${node}:${node_tmp}/kubelet.yaml"
if ! docker exec "${node}" sh -c '
  install -m 600 "$1/apiserver.yaml" /etc/kubernetes/.local-apiserver-update.yaml &&
  install -m 600 "$1/kubelet.yaml" /var/lib/kubelet/.local-kubelet-update.yaml &&
  mv /var/lib/kubelet/.local-kubelet-update.yaml /var/lib/kubelet/config.yaml &&
  systemctl restart kubelet &&
  systemctl is-active --quiet kubelet &&
  mv /etc/kubernetes/.local-apiserver-update.yaml /etc/kubernetes/manifests/kube-apiserver.yaml
' sh "${node_tmp}"; then
  echo "Feature-gate update failed; reset Docker Desktop Kubernetes before retrying." >&2
  exit 1
fi

if ! wait_features; then
  echo "Feature-gate update did not become ready; reset Docker Desktop Kubernetes before retrying." >&2
  exit 1
fi

docker exec "${node}" sh -c 'rm -rf "$1"' sh "${node_tmp}"
echo "Certificate APIs and kubelet feature gates are ready."
