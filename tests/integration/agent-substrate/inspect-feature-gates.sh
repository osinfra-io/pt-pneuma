#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
source "${SCRIPT_DIR}/../shared/cluster.sh"

assert_docker_desktop_kind_cluster
assert_local_gateway_stack_owner

kubectl version --output=json | jq -r '.serverVersion.gitVersion'
nodes="$(kubectl get nodes --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
while IFS= read -r node; do
  [ -n "${node}" ] || continue
  echo "Node: ${node}"
  docker exec "${node}" sh -c '
    if [ -f /etc/kubernetes/manifests/kube-apiserver.yaml ]; then
      echo "API server feature-gate and runtime-config flags:"
      grep -E -- "^[[:space:]]*- --(feature-gates|runtime-config)=" /etc/kubernetes/manifests/kube-apiserver.yaml || true
    fi
    if [ -f /var/lib/kubelet/config.yaml ]; then
      echo "Kubelet feature-gate configuration:"
      awk "/^featureGates:/ { print; showing=1; next } showing && /^[^[:space:]]/ { showing=0 } showing { print }" /var/lib/kubelet/config.yaml
    fi
    echo "Kubelet config arguments:"
    systemctl cat kubelet | grep -E -- "^[[:space:]]*(Environment|ExecStart).*--config" || true
    echo "Kubelet service state:"
    systemctl is-active kubelet
  '
done <<<"${nodes}"
