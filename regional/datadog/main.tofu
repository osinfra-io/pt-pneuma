# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/opentofu-kubernetes-datadog-operator//regional?ref=0a962026ce8e59d7e290b97cdd652d31d16d9ffe" # v0.3.0

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.helpers.team
}
