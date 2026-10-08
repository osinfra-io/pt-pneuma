# Gateway authentication rendering

This provider-free child renders the Authentik extension provider, browser CUSTOM authorization policies, callback route intent, and inbound identity-header stripping. Callers own all Kubernetes resources, so replacing inline rendering does not change resource addresses or require state moves.

Pass resolved host/route intent; team discovery, DNS/environment selection, cluster provider selection, and remote-state lookup remain in the caller. Keep stable policy keys to preserve hashed policy names.

Browser groups and roles must be enforced by the corresponding Authentik application bindings. CUSTOM policies authenticate browser sessions; they do not evaluate JWT group claims. Public routes produce neither CUSTOM policies nor callback routes. API-JWT inputs retain their resolved paths and claims without rendering any JWT resources.

The extension provider fails closed. The header filter removes client `x-authentik-*` headers before ext_authz supplies trusted identity. Both outputs must be deployed together.

Tests require no providers, credentials, or cluster:

```bash
tofu -chdir=regional/istio/gateway-auth init -backend=false
tofu -chdir=regional/istio/gateway-auth test
```

This cloud-independent renderer intentionally remains owned by Pneuma, alongside the resolved platform auth contract. Pneuma's Istio roots consume it relatively, and the local Istio fixture requires a checked-out Pneuma repository and uses the same source. No unpublished Arche pin or duplicate local auth implementation is needed.
