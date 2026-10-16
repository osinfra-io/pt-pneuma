#!/usr/bin/env bash

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/owner.sh"

kubectl() {
  command kubectl --context=docker-desktop "$@"
}

assert_docker_desktop_kind_cluster() {
  local nodes
  local node

  if [ "$(command kubectl config current-context)" != "docker-desktop" ]; then
    echo "Select the docker-desktop Kubernetes context explicitly; scripts never switch contexts." >&2
    return 1
  fi

  nodes="$(kubectl get nodes --output=jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')"
  [ -n "${nodes}" ] || {
    echo "Docker Desktop Kubernetes has no nodes" >&2
    return 1
  }

  while IFS= read -r node; do
    [ -n "${node}" ] || continue
    kubectl wait --for=condition=Ready "node/${node}" --timeout=15s >/dev/null ||
      {
        echo "Kubernetes node ${node} is not Ready" >&2
        return 1
      }

    if [ "$(docker inspect "${node}" --format '{{index .Config.Labels "io.x-k8s.kind.cluster"}}' 2>/dev/null)" != "desktop" ]; then
      echo "Kubernetes node ${node} is not a Docker Desktop Kind node" >&2
      return 1
    fi
  done <<<"${nodes}"
}

assert_local_gateway_stack_owner() {
  local name="${1:-${OWNER_CONFIGMAP}}"
  local namespace="${2:-${OWNER_NAMESPACE}}"
  local expected="${3:-${OWNER_VALUE}}"
  local owner

  owner="$(kubectl get configmap "${name}" --namespace="${namespace}" \
    --output=jsonpath='{.data.owner}' 2>/dev/null)" || {
    echo "Required ownership ConfigMap ${namespace}/${name} is missing" >&2
    return 1
  }

  [ "${owner}" = "${expected}" ] || {
    echo "Ownership ConfigMap ${namespace}/${name} has a different owner" >&2
    return 1
  }
}

tofu_stage() {
  local stage="$1"
  shift
  local stage_dir="${SCRIPT_DIR}/${stage}"
  local data_dir="${WORK_DIR}/${stage}/terraform-data"

  mkdir -p "${data_dir}"
  TF_DATA_DIR="${data_dir}" tofu -chdir="${stage_dir}" "$@"
}
