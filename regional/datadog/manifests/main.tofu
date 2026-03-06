# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-datadog-operator

module "kubernetes_datadog_operator_manifests" {
  source = "github.com/osinfra-io/opentofu-kubernetes-datadog-operator//regional/manifests?ref=0a962026ce8e59d7e290b97cdd652d31d16d9ffe" # v0.3.0

  lifecycle {
    enabled = true
  }

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt"
  registry       = "us-docker.pkg.dev/pt-lz-services-prod/pt-docker-virtual"
  team           = module.helpers.team
}
