# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=3978770ad88264398cd53aa2208a25c17c4b83c8" # v0.4.1

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }
}
