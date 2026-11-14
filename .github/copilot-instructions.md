# pt-pneuma

Animates Corpus projects into workload environments: GKE clusters across multiple zones, cert-manager, Istio service mesh, agentgateway, OpenBao secrets management, Datadog cluster monitoring, and OPA Gatekeeper policy enforcement.

## Local integration testing

The local integration stack is disposable Docker Desktop developer tooling. Keep checks to actual stack prerequisites and safeguards against taking over a non-empty or foreign-owned cluster. Automatically use an empty cluster; do not add claim/authorization flows, backups/rollback, or compatibility paths for hypothetical environments. Resetting Docker Desktop is an acceptable recovery.
