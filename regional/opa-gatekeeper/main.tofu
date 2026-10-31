# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=d87b538f6a2d4a0b5c4883b3de5639c16bf3d067" # v0.6.1

  for_each = local.gke_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  artifact_registry                            = local.artifact_registry
  audit_resources_limits_cpu                   = var.kubernetes_opa_gatekeeper_audit_resources_limits_cpu
  audit_resources_limits_memory                = var.kubernetes_opa_gatekeeper_audit_resources_limits_memory
  audit_resources_requests_cpu                 = var.kubernetes_opa_gatekeeper_audit_resources_requests_cpu
  audit_resources_requests_memory              = var.kubernetes_opa_gatekeeper_audit_resources_requests_memory
  controller_manager_resources_limits_cpu      = var.kubernetes_opa_gatekeeper_controller_manager_resources_limits_cpu
  controller_manager_resources_limits_memory   = var.kubernetes_opa_gatekeeper_controller_manager_resources_limits_memory
  controller_manager_resources_requests_cpu    = var.kubernetes_opa_gatekeeper_controller_manager_resources_requests_cpu
  controller_manager_resources_requests_memory = var.kubernetes_opa_gatekeeper_controller_manager_resources_requests_memory
  replicas                                     = var.kubernetes_opa_gatekeeper_replicas
}
