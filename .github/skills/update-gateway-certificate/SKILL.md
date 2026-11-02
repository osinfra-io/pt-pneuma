---
name: update-gateway-certificate
description: Safely add a team or environment-level host (such as agentgateway or authentik) to the shared Istio gateway load balancer certificate without a failing tofu apply. Use when a deployment fails with "ssl_certificate resource is already being used by targetHttpsProxies", when adding a host to the gateway certificate, or when a new GKE team is onboarded.
---

## Overview

The Istio MCI load balancer uses Google-managed certificates named `istio-gateway-mci-<hash>`, one per gateway domain set. Managed certificate domains are immutable and GCP refuses to delete a certificate the load balancer still references, so a domain change must create the new certificate first and delete the old one only after the regional workspaces have attached the new one. This is a two-PR process driven by two lists in `locals.tofu`:

- `istio_gateway_pending_teams` — team keys (e.g. `"pt-ethos"`) whose DNS zone apex is being added.
- `istio_gateway_pending_hosts` — environment-level host labels (e.g. `"agentgateway"`, `"authentik"`) served under `<label>.<env>.osinfra.io` (`<label>.osinfra.io` in production).

While an entry is listed, the certificate for the domain set without it stays in state and attached. Removing the entry deletes that old certificate.

## Steps

### 1. Confirm the change is a domain-set change

The domain set is `keys(local.gateway_dns_for_pneuma)` in `locals.tofu`: every team apex, `authentik_gateway_dns`, and `agentgateway_gateway_dns`. Identify what is being added (a team with clusters, a new host label) and whether the entry is already listed in `istio_gateway_pending_teams` or `istio_gateway_pending_hosts`. If the cause is a failed apply, check the log for the `ssl_certificate ... already being used by targetHttpsProxies` error and note the new domain that triggered it.

### 2. PR 1 — add the domain and the pending entry

In one change:

1. Add the domain (for a team, its logos workspace in `shared/helpers.tofu`; for a host, the code that adds it to the gateway DNS locals).
2. Add the team key or host label to `istio_gateway_pending_teams` or `istio_gateway_pending_hosts`.
3. Run `pre-commit autoupdate --freeze` once per session, then `pre-commit run -a`, and open the PR following the platform commit and PR conventions.

### 3. Verify the swap

After PR 1 is deployed in an environment, check that the new certificate is provisioned before relying on the new host:

```bash
gcloud compute ssl-certificates list --project <project> \
  --filter="name~istio-gateway-mci" \
  --format="table(name,managed.status,managed.domainStatus)"
```

The new certificate can take up to an hour to become `ACTIVE`; existing hosts keep serving from the old certificate meanwhile. The `check-endpoints` skill can validate the endpoints afterwards.

### 3a. One-time cleanup of the legacy certificate

The first rollout of hash-named certificates drops the old fixed-name `istio-gateway-mci` certificate from state without deleting it. Once the regional workspaces no longer reference it, delete it:

```bash
gcloud compute ssl-certificates delete istio-gateway-mci --project <project>
```

### 4. PR 2 — remove the pending entry

Only after the deployment has finished in sandbox, non-production, and production, open a follow-up PR that removes the entry from the list. The next deployment deletes the old certificate, which is no longer attached. Never merge this PR before PR 1 has fully deployed; it would trigger the same `already being used` failure.
