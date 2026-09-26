# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=cfdd7abff31aaac0b7d6b0ced3578f27a9bd5d90" # v0.5.1

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
  enable_apm                     = module.core_helpers.teams[each.value.team_key].enable_datadog_apm
  enable_usm                     = module.core_helpers.teams[each.value.team_key].enable_datadog_apm
  node_agent_container_resources = var.kubernetes_datadog_operator_node_agent_container_resources
  registry                       = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  team                           = each.value.team_key
}
