module "openbao" {
  source = "../../../../../../arche/pt-arche-kubernetes-openbao/regional"

  anti_affinity_enabled = false
  namespace             = kubernetes_namespace_v1.openbao.metadata[0].name
  replicas              = 1
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "openbao" {
  metadata {
    labels = {
      "istio.io/dataplane-mode" = "ambient"
    }

    name = "openbao"
  }
}
