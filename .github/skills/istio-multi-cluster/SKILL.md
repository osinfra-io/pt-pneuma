---
name: istio-multi-cluster
description: Sets up the Istio multi-cluster mesh for pt-pneuma by creating remote secrets across all clusters in an environment. Use this when asked to create remote secrets, set up the mesh, or connect clusters in sandbox, non-production, or production.
---

## Overview

pt-pneuma runs 6 GKE clusters per environment (3 in us-east1, 3 in us-east4). For Istio to route traffic across cluster boundaries each cluster must hold a remote secret for every other cluster. This skill creates those secrets using `istioctl create-remote-secret`.

The script discovers clusters dynamically via `gcloud` and never writes to `~/.kube/config` — it uses a temporary kubeconfig that is deleted on exit.

## When to run

Run after:
- Initial cluster provisioning in an environment
- Replacing or recreating one or more clusters
- Rotating cluster certificates

The operation is idempotent — re-running safely overwrites existing secrets.

## Steps

### 1. Determine the environment

Ask the user which environment to target if not already stated:
- `sb` — sandbox
- `np` — non-production
- `prod` — production

### 2. Confirm prerequisites

Before running, verify the required tools are available:

```bash
gcloud auth list
istioctl version --remote=false
kubectl version --client
```

If `gcloud` is not authenticated, prompt the user to run `gcloud auth login` first.

### 3. Run the script

From the root of the `pt-pneuma` repository:

```bash
./regional/istio/scripts/create-remote-secrets.sh <env>
```

For example, for sandbox:

```bash
./regional/istio/scripts/create-remote-secrets.sh sb
```

The script will:
1. Find the pt-pneuma Kubernetes project for the environment
2. List all GKE clusters in that project
3. Fetch credentials for each cluster into a temp kubeconfig
4. Create and apply remote secrets for every cluster pair (30 total for 6 clusters)
5. Delete the temp kubeconfig on exit

### 4. Verify the mesh

After the script completes, confirm the mesh is healthy:

```bash
./regional/istio/scripts/check-health.sh <env>
```

A healthy mesh shows all proxies as `SYNCED` in the `proxy-status` output and no errors in `istioctl analyze`.

## Troubleshooting

**No project found** — `gcloud` account lacks access to the pt-pneuma Kubernetes project. Run `gcloud auth list` and check the active account has the `roles/container.clusterViewer` role.

**`istioctl` version mismatch** — Run `istioctl version --context=<context>` to check the deployed version and install a matching `istioctl` binary.

**Proxies not synced after applying secrets** — Restart Istiod to force a re-sync:
```bash
kubectl rollout restart deployment/istiod -n istio-system --context=<context>
```
