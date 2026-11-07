# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional/manifests?ref=3d80c02edd2ab902f153f15830a0278d5d248fd7" # v0.2.2

  for_each = local.agentgateway_clusters

  providers = {
    kubernetes = kubernetes.by_cluster
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
  proxy_env = local.proxy_env
}
