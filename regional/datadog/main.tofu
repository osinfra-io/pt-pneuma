# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=3cffd6e30ba9bf2d7ae465716fc49a517d008ab5" # v0.3.6

  lifecycle {
    enabled = local.enable_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.core_helpers.team
}
