---
name: update-gateway-certificate
description: Safely add a team or environment-level host (such as agentgateway or authentik) to the shared Istio gateway load balancer certificate without a failing tofu apply. Use when a deployment fails with "ssl_certificate resource is already being used by targetHttpsProxies", when adding a host to the gateway certificate, or when a new GKE team is onboarded.
---

## Overview

The Istio MCI load balancer uses Google-managed certificates named `istio-gateway-mci-<hash>`, one per gateway domain set. Managed certificate domains are immutable and GCP refuses to delete a certificate the load balancer still references, so a domain change must create the new certificate first and delete the old one only after the regional workspaces have attached the new one. This is a three-PR process driven by these values in `locals.tofu`:

- `istio_gateway_attach_retained_certificates` — `true` while the old and new certificates are both attached; `false` detaches the old one while keeping it.
- `istio_gateway_legacy_certificate_names` — the pre-hash `istio-gateway-mci` certificate, attached until the new one is `ACTIVE`.
- `istio_gateway_pending_teams` — team keys (e.g. `"pt-ethos"`) whose DNS zone apex is being added.
- `istio_gateway_pending_hosts` — environment-level host labels (e.g. `"agentgateway"`, `"authentik"`) served under `<label>.<env>.osinfra.io` (`<label>.osinfra.io` in production).

While a pending entry is listed, the certificate for the domain set without it stays in state. Removing the entry deletes that old certificate, so detach it first.

## Steps

### 1. Confirm the change is a domain-set change

The domain set is `keys(local.gateway_dns_for_pneuma)` in `locals.tofu`: every team apex, `authentik_gateway_dns`, and `agentgateway_gateway_dns`. Identify what is being added (a team with clusters, a new host label) and whether the entry is already listed in `istio_gateway_pending_teams` or `istio_gateway_pending_hosts`. If the cause is a failed apply, check the log for the `ssl_certificate ... already being used by targetHttpsProxies` error and note the new domain that triggered it.

### 2. PR 1 — add the domain and retain the old certificate

In one change:

1. Add the domain (for a team, its logos workspace in `shared/helpers.tofu`; for a host, the code that adds it to the gateway DNS locals).
2. Add the team key or host label to `istio_gateway_pending_teams` or `istio_gateway_pending_hosts`.
3. Run `pre-commit autoupdate --freeze` once per session, then `pre-commit run -a`, and open the PR following the platform commit and PR conventions.

### 3. Verify the new certificate

After PR 1 is deployed in every environment, check that the new certificate is provisioned:

```bash
gcloud compute ssl-certificates list --project <project> \
  --filter="name~istio-gateway-mci" \
  --format="table(name,managed.status,managed.domainStatus)"
```

The new certificate can take up to an hour to become `ACTIVE`; existing hosts keep serving from the old certificate meanwhile. Do not continue until it is `ACTIVE`. The `check-endpoints` skill can validate the endpoints afterwards.

### 4. PR 2 — detach the old certificate

Set `istio_gateway_attach_retained_certificates = false` (and, during the first hash-named rollout, `istio_gateway_legacy_certificate_names = []`). The old certificates stay in state but the regional workspaces stop attaching them. After it has deployed in every environment, confirm the load balancer no longer references them:

```bash
gcloud compute target-https-proxies list --project <project> --format="table(name,sslCertificates)"
```

### 5. PR 3 — delete the old certificate

Only once the proxy no longer lists the old certificate, remove the pending entry and reset `istio_gateway_attach_retained_certificates = true`. The next deployment deletes the old certificate. Never merge this before PR 2 has fully deployed; it would trigger the `already being used` failure. After the first hash-named rollout, also delete the orphaned legacy certificate manually:

```bash
gcloud compute ssl-certificates delete istio-gateway-mci --project <project>
```
