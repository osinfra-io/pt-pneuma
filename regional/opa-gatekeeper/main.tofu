# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=2ecdab604ad3b45bd355a4ccda835f14f38c111f" # v0.3.1

  for_each = local.gke_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
}
