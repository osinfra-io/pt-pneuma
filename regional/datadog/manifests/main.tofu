# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=2d7076254809ba3faf18bd1357b7e788538a19a7" # v0.4.0

  for_each = local.datadog_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = each.value.team_key
  enable_apm     = module.core_helpers.teams[each.value.team_key].enable_datadog_apm
  enable_usm     = module.core_helpers.teams[each.value.team_key].enable_datadog_apm
  registry       = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  team           = each.value.team_key
}
