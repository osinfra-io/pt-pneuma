# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional/manifests?ref=6f15a7fcf9fa1a05979905b60a122a066e8b4c4d" # v0.2.1

  for_each = local.agentgateway_clusters

  providers = {
    kubernetes = kubernetes.by_cluster
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
  proxy_env = local.proxy_env
}
