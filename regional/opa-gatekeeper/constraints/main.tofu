# Kubernetes OPA Gatekeeper Constraints Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_constraints" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/constraints?ref=6afb7c74aca435820ec596c0d4a6b4549465cbc3" # v0.4.7

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
