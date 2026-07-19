---
name: create-kubeconfig
description: Creates a local kubeconfig with credentials for all detected clusters in an environment, using their friendly cluster names as context names. Use when asked to create a kubeconfig, set up kubectl access, or configure cluster credentials.
---

## Overview

This skill creates credentials in your local `~/.kube/config` for every GKE cluster in an
environment. Clusters are discovered automatically by scanning every GCP project labeled
`labels.repository=pt-corpus` for the environment — no team names or cluster lists needed.
Each cluster context is renamed from the default gcloud format
(`gke_{project}_{zone}_{name}`) to the friendly cluster name (e.g. `pt-pneuma-us-east1-b`).

## When to run

Run when:
- Setting up a new local environment to work with clusters
- A new cluster has been provisioned and you need to add it to your kubeconfig
- Rebuilding kubeconfig after a machine rebuild or credential rotation

## Steps

### 1. Determine the environment

Ask the user which environment to target if not already stated:
- `sb` — sandbox
- `nonprod` — non-production
- `prod` — production

### 2. Confirm prerequisites

The script needs `gcloud`, `kubectl`, and an authenticated session:

```bash
gcloud auth list
kubectl version --client
```

If `gcloud` is not authenticated, prompt the user to run `gcloud auth login` first.

### 3. Run the script

From the root of the `pt-pneuma` repository:

```bash
./scripts/create-kubeconfig.sh <env>
```

Examples:

```bash
./scripts/create-kubeconfig.sh sb
./scripts/create-kubeconfig.sh nonprod
./scripts/create-kubeconfig.sh prod
```

The script will:
1. Find all GCP projects labeled `labels.repository=pt-corpus` for the environment
2. Scan each project for GKE clusters
3. Fetch credentials for every discovered cluster into `~/.kube/config`
4. Rename each context from the default gcloud name to the friendly cluster name
5. Print the list of available contexts

### 4. Verify

After the script completes, confirm the contexts are available:

```bash
kubectl config get-contexts
```

Switch to a specific cluster:

```bash
kubectl config use-context pt-pneuma-us-east1-b
```

## Troubleshooting

**No pt-corpus projects found** — `gcloud` account lacks access to the pt-corpus projects,
or no projects are labeled `labels.repository=pt-corpus` for the environment.

**No clusters found** — all discovered projects exist but none have GKE clusters. Verify
cluster provisioning is complete in pt-pneuma.

**Context rename conflict** — if a context with the friendly name already exists, the script
deletes it before renaming. Re-running is safe and idempotent.

**Permission denied on cluster** — ensure your Google identity has the
`container.developer` role on the project, or contact the platform team.
