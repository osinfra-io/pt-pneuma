# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional?ref=6f15a7fcf9fa1a05979905b60a122a066e8b4c4d" # v0.2.1

  for_each = local.agentgateway_clusters

  providers = {
    helm       = helm.by_cluster
    kubernetes = kubernetes.by_cluster
  }

  labels    = module.core_helpers.labels
  namespace = kubernetes_namespace_v1.agentgateway[each.key].metadata[0].name
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "agentgateway" {
  for_each = local.agentgateway_clusters
  provider = kubernetes.by_cluster

  metadata {
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }

    name = local.namespace
  }
}
