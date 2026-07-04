---
name: istio-multi-cluster
description: Sets up the Istio multi-cluster mesh by creating remote secrets across all clusters in an environment. Automatically discovers all teams' clusters — no team names needed. Use this when asked to create remote secrets, set up the mesh, or connect clusters in sandbox, non-production, or production.
---

## Overview

Clusters in a multi-cluster Istio mesh must each hold a remote secret for every other cluster. This skill creates those secrets using `istioctl create-remote-secret`.

The scripts discover clusters automatically by scanning every GCP project labeled `labels.repository=pt-corpus` for the environment. Any project that has GKE clusters is included — adding a new team's clusters is picked up automatically with no script changes.

## When to run

Run after:
- Initial cluster provisioning in an environment
- Adding a new team's clusters to the mesh
- Replacing or recreating one or more clusters
- Rotating cluster certificates

The operation is idempotent — re-running safely overwrites existing secrets (`kubectl apply` outputs `configured` instead of `created`).

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

Examples:

```bash
./regional/istio/scripts/create-remote-secrets.sh sb
./regional/istio/scripts/create-remote-secrets.sh nonprod
./regional/istio/scripts/create-remote-secrets.sh prod
```

The script will:
1. Find all GCP projects labeled `labels.repository=pt-corpus` for the environment
2. Scan each project for GKE clusters
3. Fetch credentials for every discovered cluster into a temp kubeconfig
4. Create and apply remote secrets for every cross-cluster pair (including cross-team)
5. Delete the temp kubeconfig on exit

### 4. Verify the mesh

After the script completes, confirm the mesh is healthy:

```bash
./regional/istio/scripts/check-health.sh <env>
```

This runs three checks per cluster across all discovered clusters:
- `istioctl analyze` — configuration warnings or errors
- `istioctl proxy-status` — all proxies should be `SYNCED`
- `istioctl remote-clusters` — all peer clusters should show `synced`

## Troubleshooting

**No projects found** — `gcloud` account lacks access to the pt-corpus projects, or no projects are labeled `labels.repository=pt-corpus` for the environment.

**No clusters found** — all discovered projects exist but none have GKE clusters. Verify cluster provisioning is complete.

**`istioctl` version mismatch** — Run `istioctl version --context=<context>` to check the deployed version and install a matching binary.

**Proxies not synced after applying secrets** — Restart Istiod to force a re-sync:
```bash
kubectl rollout restart deployment/istiod -n istio-system --context=<context>
```

**A cluster is missing from `remote-clusters`** — Re-run the script; it is idempotent and will create any missing secrets.
