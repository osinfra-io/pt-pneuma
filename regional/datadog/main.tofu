# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=77145fbc92a5eb75a5a6fa90939730730fd85d18" # v0.3.5

  lifecycle {
    enabled = local.enable_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.core_helpers.team
}
