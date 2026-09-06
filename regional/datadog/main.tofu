# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=62a81283544eac8801598bdde712cabc7e9cdd53" # v0.4.3

  for_each = local.datadog_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = each.value.team_key
}
