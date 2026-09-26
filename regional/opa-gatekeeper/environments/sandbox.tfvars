# The audit and admission controllers share the `manager` container name in metrics. Across both
# clusters it averages about 100m CPU / 94Mi memory per pod, with periodic audit bursts reaching
# 801m CPU / 145Mi. Reserve the steady workload and retain burst headroom.

kubernetes_opa_gatekeeper_audit_resources_limits_cpu                   = "1"
kubernetes_opa_gatekeeper_audit_resources_limits_memory                = "256Mi"
kubernetes_opa_gatekeeper_audit_resources_requests_cpu                 = "250m"
kubernetes_opa_gatekeeper_audit_resources_requests_memory              = "160Mi"
kubernetes_opa_gatekeeper_controller_manager_resources_limits_cpu      = "500m"
kubernetes_opa_gatekeeper_controller_manager_resources_limits_memory   = "256Mi"
kubernetes_opa_gatekeeper_controller_manager_resources_requests_cpu    = "50m"
kubernetes_opa_gatekeeper_controller_manager_resources_requests_memory = "128Mi"
