# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=8b7a49d26f08f88f90ce01bafe747f816c3715b1" # v0.5.7

  for_each = local.datadog_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  api_key         = var.datadog_api_key
  app_key         = var.datadog_app_key
  cluster_prefix  = each.value.team_key
  limits_cpu      = var.kubernetes_datadog_operator_limits_cpu
  limits_memory   = var.kubernetes_datadog_operator_limits_memory
  requests_cpu    = var.kubernetes_datadog_operator_requests_cpu
  requests_memory = var.kubernetes_datadog_operator_requests_memory
}
