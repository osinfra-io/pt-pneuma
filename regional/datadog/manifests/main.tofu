# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=c525e20c8b9bbfcb7c1e48d771e0961a0830b1e5" # v0.3.8

  lifecycle {
    enabled = module.core_helpers.teams["pt-pneuma"].enable_platform_managed_datadog
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  enable_apm     = module.core_helpers.teams["pt-pneuma"].enable_datadog_apm
  enable_usm     = module.core_helpers.teams["pt-pneuma"].enable_datadog_apm
  registry       = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"
  team           = module.core_helpers.team
}
