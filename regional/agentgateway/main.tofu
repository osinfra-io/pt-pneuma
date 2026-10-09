# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional?ref=9a362bdc6430338286fa206f1ae7f3009b03bd09" # v0.1.0

  for_each = local.agentgateway_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
}
