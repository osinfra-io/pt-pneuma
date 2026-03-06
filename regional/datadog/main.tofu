# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/opentofu-kubernetes-datadog-operator//regional?ref=6f57f25c07ff7553af8fc6dbc77a1398df5a54af" # v0.3.1

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.helpers.team
}
