# Browser-auth rendering regression

This cloud-free test evaluates the **actual Pneuma locals** through symlinks, substitutes only team/remote-state inputs, and checks their browser policy, callback and extension-provider outputs against `regional/istio/gateway-auth`. It also retains assertions for native API-JWT principal/audience/group/role DENY enforcement.

Run from the repository root:

```bash
regional/istio/tests/browser-auth/check.sh
```

The script selects a synthetic workspace solely to exercise the existing workspace-name parser. No state backend, providers, cluster, or credentials are accessed.

Pneuma roots and the local Istio fixture consume the same provider-free rendering module by relative source. The renderer owns no resources; the extraction keeps existing Kubernetes resource addresses and needs no state moves. Local Istio testing requires the Pneuma checkout.
