# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional/manifests?ref=fa2b1f6593e4ad1c1e5e8614e6510afc3f044c36" # v0.3.2

  lifecycle {
    enabled = true
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  registry       = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"
  team           = module.helpers.team
}
