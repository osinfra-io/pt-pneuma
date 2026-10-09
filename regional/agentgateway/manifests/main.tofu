# Kubernetes Agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional/manifests?ref=9173f481bcf965db71694488ee9664887f95c588" # agentgateway-admin-routing testing

  for_each = local.gateway_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  labels         = module.core_helpers.labels
  namespace      = local.namespace
  proxy_replicas = var.proxy_replicas
}
