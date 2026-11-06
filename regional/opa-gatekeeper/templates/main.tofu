# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=c06d69f8402339647e8060f893a400aa7051096e" # v0.6.2

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }
}
