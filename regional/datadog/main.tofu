# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=42387ede2c7c7ca6021e656c977209ec94c8ceae" # v0.3.3

  lifecycle {
    enabled = local.enable_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.core_helpers.team
}
