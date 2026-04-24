# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=c525e20c8b9bbfcb7c1e48d771e0961a0830b1e5" # v0.3.8

  lifecycle {
    enabled = local.enable_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.core_helpers.team
}
