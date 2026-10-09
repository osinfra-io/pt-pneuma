# Kubernetes Agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional?ref=9173f481bcf965db71694488ee9664887f95c588" # agentgateway-admin-routing testing

  for_each = local.gateway_clusters

  depends_on = [kubernetes_manifest.admin_closed]

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "admin_closed" {
  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = local.admin_closed_manifest
}
