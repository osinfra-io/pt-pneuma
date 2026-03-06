# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/opentofu-kubernetes-datadog-operator//regional/manifests?ref=6f57f25c07ff7553af8fc6dbc77a1398df5a54af" # v0.3.1

  lifecycle {
    enabled = true
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  registry       = "us-docker.pkg.dev/pt-lz-services-prod/pt-docker-virtual"
  team           = module.helpers.team
}
