# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=fa2b1f6593e4ad1c1e5e8614e6510afc3f044c36" # v0.3.2

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.helpers.team
}
