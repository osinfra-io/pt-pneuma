# Gateway authentication rendering

This provider-free child renders the Authentik extension provider, browser CUSTOM authorization policies, callback route intent, and inbound identity-header stripping. Callers own all Kubernetes resources, so replacing inline rendering does not change resource addresses or require state moves.

Pass resolved host/route intent; team discovery, DNS/environment selection, cluster provider selection, and remote-state lookup remain in the caller. Keep stable policy keys to preserve hashed policy names.

Legacy browser groups and roles remain enforced by the corresponding Authentik application bindings. CUSTOM policies authenticate browser sessions; they do not evaluate JWT group claims. Public routes produce neither CUSTOM policies nor callback routes. API-JWT inputs retain their resolved paths and claims without rendering any JWT resources.

The extension provider fails closed. The header filter removes client `x-authentik-*` headers before ext_authz supplies trusted identity. Both outputs must be deployed together.

For managed application groups, pass the current environment's `application_group_members` and deploy `browser_authorization_filter_manifests` alongside those outputs. The guard runs after successful forward-auth and authorizes each path against current declarations, not cached group claims. It requires the `x-authentik-osinfra-google-email` header from the Authentik module's verified Google proxy mapping; ordinary email headers cannot grant managed access. OR applies within each requirement list and AND between group and role lists. Ambiguous encoded paths fail closed.

The `team-access` child selects explicit environment lists from either Logos declarations or core-helper outputs. It creates no users, resources, or credentials. Unreleased cloud consumers remain restricted to their existing host-scoped policies; local fixtures exercise the new guard with checked-out sources.

Tests require no providers, credentials, or cluster:

```bash
tofu -chdir=regional/istio/gateway-auth init -backend=false
tofu -chdir=regional/istio/gateway-auth test
python3 -m unittest discover -s regional/istio/gateway-auth/tests -p 'test_browser_authorization.py'
```

The Python test executes the actual rendered guard and requires the `lua` interpreter. Real OAuth sign-in and old-session revocation still require the owned local integration fixture.

This cloud-independent renderer intentionally remains owned by Pneuma, alongside the resolved platform auth contract. Pneuma's Istio roots consume it relatively, and the local Istio fixture requires a checked-out Pneuma repository and uses the same source. No unpublished Arche pin or duplicate local auth implementation is needed.
