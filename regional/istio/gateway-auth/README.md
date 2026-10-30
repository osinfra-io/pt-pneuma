# Gateway authentication rendering

This provider-free child renders the Authentik extension provider, browser CUSTOM authorization policies, callback route intent, and inbound identity-header stripping. Callers own all Kubernetes resources, so replacing inline rendering does not change resource addresses or require state moves.

Pass resolved host/route intent; team discovery, DNS/environment selection, cluster provider selection, and remote-state lookup remain in the caller. Keep stable policy keys to preserve hashed policy names.

Authentik applications and their access policies authenticate and authorize browser sessions through `ext_authz`. Browser routes sharing a host must declare identical group and role requirements; use separate application hosts for different access rules. The gateway renders no post-auth authorization Lua or user email membership tables. Public routes produce neither CUSTOM policies nor callback routes. API-JWT inputs retain their resolved paths and claims without rendering any JWT resources.

The checked-out Arche Authentik configuration enforces OR within groups and roles, AND between those lists, and linked verified Google identity for team-qualified requirements. Its expression policies disable policy-result caching. Release that module and update Pneuma's pinned Authentik configuration source before deploying this gateway change; the older per-group bindings do not provide equivalent enforcement. Apply the Authentik migration before removing the gateway guard.

The extension provider fails closed. The header filter removes client `x-authentik-*` headers before ext_authz supplies trusted identity. Both outputs must be deployed together.

Managed application group memberships are assigned in Authentik from verified Google identities by the Authentik configuration module. The gateway does not independently authorize email headers. The inbound header-stripping filter remains to prevent client-supplied identity headers reaching upstream applications.

The embedded outpost caches authenticated claims in its session store. Authentik 2026.8.5 uses the proxy provider's `access_token_validity` as the session lifetime; the provider is explicitly configured for ten minutes, with a maximum cache lifetime of ten minutes plus one second. A new session sees current membership; an existing session can retain a removed group until that bound expires. Membership changes update Authentik configuration only and do not require a gateway redeployment.

The `team-access` child selects explicit environment lists from either Logos declarations or core-helper outputs for Authentik configuration. It creates no users, resources, or credentials. Cloud consumers and local fixtures both use host-scoped Authentik policies.

Tests require no providers, credentials, or cluster:

```bash
tofu -chdir=regional/istio/gateway-auth init -backend=false
tofu -chdir=regional/istio/gateway-auth test
```

The browser-auth regression also exercises the remaining header-stripping Lua with `regional/istio/tests/browser-auth/check.sh`. Real OAuth sign-in and the ten-minute existing-session revocation bound require the owned local integration fixture.

This cloud-independent renderer intentionally remains owned by Pneuma, alongside the resolved platform auth contract. Pneuma's Istio roots consume it relatively, and the local Istio fixture requires a checked-out Pneuma repository and uses the same source. No unpublished Arche pin or duplicate local auth implementation is needed.
