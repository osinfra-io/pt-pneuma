# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=8b7a49d26f08f88f90ce01bafe747f816c3715b1" # v0.5.7

  for_each = local.datadog_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  api_key                        = var.datadog_api_key
  app_key                        = var.datadog_app_key
  cluster_agent_limits_cpu       = var.kubernetes_datadog_operator_cluster_agent_limits_cpu
  cluster_agent_limits_memory    = var.kubernetes_datadog_operator_cluster_agent_limits_memory
  cluster_agent_requests_cpu     = var.kubernetes_datadog_operator_cluster_agent_requests_cpu
  cluster_agent_requests_memory  = var.kubernetes_datadog_operator_cluster_agent_requests_memory
  cluster_prefix                 = each.value.team_key
  enable_apm                     = true
  enable_usm                     = true
  node_agent_container_resources = var.kubernetes_datadog_operator_node_agent_container_resources
  registry                       = local.artifact_registry
  team                           = each.value.team_key
}
