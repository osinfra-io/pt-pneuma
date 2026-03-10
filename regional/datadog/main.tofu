# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-datadog-operator//regional?ref=76e955daac881c316bfcd6d6bb0eb3f9d27d2aa1" # v0.3.2

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = module.helpers.team
}
