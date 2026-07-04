---
name: istio-multi-cluster
description: Sets up the Istio multi-cluster mesh by creating remote secrets across all clusters in an environment. Supports multiple teams (e.g., pt-pneuma and pt-kryptos) in a single run. Use this when asked to create remote secrets, set up the mesh, or connect clusters in sandbox, non-production, or production.
---

## Overview

Clusters in a multi-cluster Istio mesh must each hold a remote secret for every other cluster. This skill creates those secrets using `istioctl create-remote-secret`.

The scripts discover clusters dynamically via `gcloud` across one or more teams and never write to `~/.kube/config` — they use a temporary kubeconfig that is deleted on exit.

Each team's GKE clusters live in a separate GCP project discovered via `labels.team=<team> labels.repository=pt-corpus`. When multiple teams share the mesh (e.g., pt-pneuma as the hub host and pt-kryptos as a member team), pass all team names so cross-team secrets are created correctly.

## When to run

Run after:
- Initial cluster provisioning in an environment
- Adding a new team's clusters to the mesh
- Replacing or recreating one or more clusters
- Rotating cluster certificates

The operation is idempotent — re-running safely overwrites existing secrets (`kubectl apply` outputs `configured` instead of `created`).

## Steps

### 1. Determine the environment and teams

Ask the user which environment to target if not already stated:
- `sb` — sandbox
- `nonprod` — non-production
- `prod` — production

Ask which teams are in the mesh. For a pt-pneuma-only mesh pass only `pt-pneuma`. When member teams (e.g., `pt-kryptos`) are in the mesh, include all of them so cross-team secrets are created.

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
./regional/istio/scripts/create-remote-secrets.sh <env> [team...]
```

Examples:

```bash
# pt-pneuma only (sandbox)
./regional/istio/scripts/create-remote-secrets.sh sb

# pt-pneuma + pt-kryptos (sandbox)
./regional/istio/scripts/create-remote-secrets.sh sb pt-pneuma pt-kryptos

# pt-pneuma + pt-kryptos (non-production)
./regional/istio/scripts/create-remote-secrets.sh nonprod pt-pneuma pt-kryptos
```

The script will:
1. For each team, find its Kubernetes project for the environment
2. List all GKE clusters across all teams
3. Fetch credentials for every cluster into a temp kubeconfig
4. Create and apply remote secrets for every cross-cluster pair (including cross-team)
5. Delete the temp kubeconfig on exit

### 4. Verify the mesh

After the script completes, confirm the mesh is healthy:

```bash
./regional/istio/scripts/check-health.sh <env> [team...]
```

Examples:

```bash
./regional/istio/scripts/check-health.sh sb pt-pneuma pt-kryptos
```

This runs three checks per cluster:
- `istioctl analyze` — configuration warnings or errors
- `istioctl proxy-status` — all proxies should be `SYNCED`
- `istioctl remote-clusters` — all peer clusters should show `synced`

To confirm cross-team connectivity, run `istioctl remote-clusters` against a cluster and verify all clusters from all teams appear as `synced`.

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

**Cross-team clusters missing from `remote-clusters`** — Ensure you passed all team names to the script. Re-run with the full team list to create any missing cross-team secrets.
