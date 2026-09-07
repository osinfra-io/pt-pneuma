# Kubernetes OPA Gatekeeper Constraints Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_constraints" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/constraints?ref=aedff60d2e1c5a2aacf17e64548f91dc8009ab7e" # v0.4.5

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "gateway_auth_guardrail_constraint" {
  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = local.gateway_auth_guardrail_constraint_manifest
}
