# Shared Authentik authentication

Pneuma's cloud configuration and the local Kubernetes Authentik fixture call this child module for the same brand, custom authentication flow, stage order, conditional password/MFA policies, and identification settings. Callers resolve built-in stage/policy IDs and pass their domain and titles; cloud discovery and imports remain in the root.

The shared identification stage is managed by the Arche configuration module, with settings from this module, and is reused by both the built-in and custom flows. Google sources and browser group policies remain caller-owned. Disabling the custom flow leaves the identification settings available for production/non-production.

Root `moved.tofu` preserves all four existing cloud resource addresses. The local fixture moves its existing Development brand into this module rather than creating a competing domain brand.

Run mocked regressions with `tofu init -backend=false` and `tofu test` in this directory. For live verification, use `/platform-grouping:test-local-gateway-stack` from the [platform-grouping plugin](https://github.com/osinfra-io/pt-ai-plugins/tree/main/plugins/platform-grouping).
