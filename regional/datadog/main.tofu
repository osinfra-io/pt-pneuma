# Kubernetes Datadog Operator Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-datadog-operator

module "kubernetes_datadog_operator" {
  source = "github.com/osinfra-io/opentofu-kubernetes-datadog-operator//regional?ref=ae46c0b60f4167c02bbde0554efdc28dd3c036c0" # v0.2.0

  api_key        = var.datadog_api_key
  app_key        = var.datadog_app_key
  cluster_prefix = "pt-pneuma"
}
