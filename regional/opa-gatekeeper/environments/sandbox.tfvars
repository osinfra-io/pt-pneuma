# The audit controller measured a flat 40m CPU - exactly its default limit - so it was being
# throttled continuously; with the limit raised it settles around 121m. Memory sat at 94Mi
# against a 128Mi limit. Limits do not consume scheduling budget, so raising both is free.
#
# Requests are deliberately left at the module defaults. Both controllers overrun them, but the
# sandbox nodes run at roughly 46% actual CPU, so there is no contention to protect against and
# raising the requests would cost scheduling budget the clusters do not have.

kubernetes_opa_gatekeeper_audit_resources_limits_cpu    = "150m"
kubernetes_opa_gatekeeper_audit_resources_limits_memory = "256Mi"
