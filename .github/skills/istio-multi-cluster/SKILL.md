---
name: istio-multi-cluster
description: Sets up the Istio multi-cluster mesh for a team by creating remote secrets across all clusters in an environment. Use this when asked to create remote secrets, set up the mesh, or connect clusters in sandbox, non-production, or production.
---

## Overview

Clusters in a multi-cluster Istio mesh must each hold a remote secret for every other cluster. This skill creates those secrets using `istioctl create-remote-secret`.

The scripts discover clusters dynamically via `gcloud` and never write to `~/.kube/config` — they use a temporary kubeconfig that is deleted on exit.

The scripts work for any team that has GKE clusters created by pt-corpus. The `team` argument maps to the `labels.team` GCP project label. It defaults to `pt-pneuma` but can be overridden for any team (e.g., `st-ethos`).

## When to run

Run after:
- Initial cluster provisioning in an environment
- Replacing or recreating one or more clusters
- Rotating cluster certificates

The operation is idempotent — re-running safely overwrites existing secrets (`kubectl apply` outputs `configured` instead of `created`).

## Steps

### 1. Determine the environment and team

Ask the user which environment to target if not already stated:
- `sb` — sandbox
- `nonprod` — non-production
- `prod` — production
```

The script will:
1. Find the Kubernetes project for the team and environment
2. List all GKE clusters in that project
3. Fetch credentials for each cluster into a temp kubeconfig
4. Create and apply remote secrets for every cluster pair
5. Delete the temp kubeconfig on exit

### 4. Verify the mesh

After the script completes, confirm the mesh is healthy:

```bash
./regional/istio/scripts/check-health.sh <env> [team]
```

This runs three checks per cluster:
- `istioctl analyze` — configuration warnings or errors
- `istioctl proxy-status` — all proxies should be `SYNCED`
- `istioctl remote-clusters` — all peer clusters should show `synced`

## Troubleshooting

**No project found** — `gcloud` account lacks access to the team's Kubernetes project, or the team label doesn't match. Run:
```bash
gcloud projects list --filter="labels.team=<team> labels.repository=pt-corpus"
```

**`istioctl` version mismatch** — Run `istioctl version --context=<context>` to check the deployed version and install a matching binary.

**Proxies not synced after applying secrets** — Restart Istiod to force a re-sync:
```bash
kubectl rollout restart deployment/istiod -n istio-system --context=<context>
```

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
- `nonprod` — non-production
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

To confirm every cluster sees all its peers as connected, run `istioctl remote-clusters` against each cluster. Each cluster should list all 5 other clusters with status `synced`:

```bash
istioctl remote-clusters --context=<context>
```

Expected output (6 clusters → each row shows a remote peer):

```
NAME                     SECRET                                          STATUS    ISTIOD
pt-pneuma-us-east1-b-sb                                                  synced    istiod-...
pt-pneuma-us-east1-c     istio-system/istio-remote-secret-...            synced    istiod-...
...
```

The local cluster appears in the list without a secret (it is self-discovered). All remote entries must show `synced`. If any show `timeout` or are missing, re-run `create-remote-secrets.sh` for that environment.

## Troubleshooting

**No project found** — `gcloud` account lacks access to the pt-pneuma Kubernetes project. Run `gcloud auth list` and check the active account has the `roles/container.clusterViewer` role.

**`istioctl` version mismatch** — Run `istioctl version --context=<context>` to check the deployed version and install a matching `istioctl` binary.

**Proxies not synced after applying secrets** — Restart Istiod to force a re-sync:
```bash
kubectl rollout restart deployment/istiod -n istio-system --context=<context>
```
