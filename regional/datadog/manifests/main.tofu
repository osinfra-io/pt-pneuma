# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=76e955daac881c316bfcd6d6bb0eb3f9d27d2aa1" # v0.3.2

  lifecycle {
    enabled = false
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  registry       = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"
  team           = module.helpers.team
}
