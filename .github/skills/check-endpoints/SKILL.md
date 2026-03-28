---
name: check-endpoints
description: Validates istio-test DNS endpoints for all clusters in an environment by discovering them from Cloud DNS records. Use this when asked to check endpoints, validate cluster health, test cluster connectivity, or verify cluster DNS.
---

## Overview

Every GKE cluster exposes an istio-test metadata endpoint via its zonal DNS name. The global (MCI) endpoint exposes a health check. This skill runs a script that discovers all endpoints from DNS A records in the team's Cloud DNS managed zone, then validates every endpoint is responding correctly.

The script works for any team that has a DNS zone managed in the pt-corpus shared VPC host project. It only needs the environment and DNS subdomain (e.g., `pneuma`, `ethos`).

## When to run

Run when:
- Verifying cluster health after a deployment or change
- Troubleshooting DNS or ingress issues
- Validating a new cluster is reachable
- Routine health checks across an environment

## Steps

### 1. Determine the environment and subdomain

Ask the user which environment to target if not already stated:
- `sb` — sandbox
- `nonprod` — non-production
- `prod` — production

Ask which subdomain if not obvious from context (e.g., `pneuma`, `ethos`).

### 2. Confirm prerequisites

The script needs `curl` and `gcloud` — no kubeconfig or kubectl required:

```bash
gcloud auth list
curl --version
```

If `gcloud` is not authenticated, prompt the user to run `gcloud auth login` first.

### 3. Run the script

From the root of the `pt-pneuma` repository:

```bash
./regional/istio/scripts/check-endpoints.sh <env> <subdomain>
```

Examples:

```bash
# pneuma sandbox
./regional/istio/scripts/check-endpoints.sh sb pneuma

# ethos non-production
./regional/istio/scripts/check-endpoints.sh np ethos
```

The script will:
1. Find the pt-corpus shared VPC host project for the environment
2. List all DNS A records in the team's managed zone
3. Curl each zonal endpoint at `/istio-test/metadata/cluster-name` and validate the returned cluster name contains the expected zone
4. Curl the global endpoint at `/istio-test/health` and check for HTTP 200
5. Print a pass/fail summary and exit non-zero if any check failed

### 4. Interpret the results

**All passed** — every endpoint is responding correctly and returning the expected identity.

**Zonal endpoint failed** — the cluster's ingress or istio-test deployment may be unhealthy. Check:
- Is the istio-test pod running in the cluster?
- Is the Istio ingress gateway healthy?
- Does the DNS record resolve to the correct IP?

**Global endpoint failed** — the multi-cluster ingress (MCI) may be misconfigured or all backend clusters are unhealthy.

## Troubleshooting

**No pt-corpus project found** — `gcloud` account lacks access to the pt-corpus shared VPC host project for the environment.

**No A records found** — the managed zone does not exist or has no A records. Verify the zone name:
```bash
gcloud dns managed-zones list --project=<pt-corpus-project>
```

**DNS resolution failed (HTTP 000)** — the DNS record exists but the hostname is not resolvable from the current machine. Verify with:
```bash
dig +short <zone>.<subdomain>.<env>.osinfra.io
```

**HTTP 403 (RBAC: access denied)** — the Istio authorization policy is blocking the request. The `/istio-test/metadata/cluster-name` path should be open; if it returns 403 check the AuthorizationPolicy in the cluster.

**Wrong cluster name** — the endpoint responded but the cluster name does not contain the expected zone. This usually means DNS is pointing to the wrong cluster or load balancer.

**Timeout** — the endpoint did not respond within 15 seconds. Check that the cluster's external IP is reachable and the istio-test service is running.
