# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional?ref=3d80c02edd2ab902f153f15830a0278d5d248fd7" # v0.2.2

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
