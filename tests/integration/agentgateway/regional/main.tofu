module "agentgateway" {
  source = "../../../../../../arche/pt-arche-kubernetes-agentgateway/regional"

  crds_postrender = local.crds_postrender
  namespace       = kubernetes_namespace_v1.agentgateway.metadata[0].name
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "agentgateway" {
  metadata {
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }

    name = "agentgateway"
  }
}
