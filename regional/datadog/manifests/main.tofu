# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=3cffd6e30ba9bf2d7ae465716fc49a517d008ab5" # v0.3.6

  lifecycle {
    enabled = module.core_helpers.teams["pt-pneuma"].enable_platform_managed_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  registry       = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"
  team           = module.core_helpers.team
}
