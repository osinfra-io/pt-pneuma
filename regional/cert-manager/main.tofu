# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=07f3ccd0991a9525d7a050d675688c2fe51003e4" # v0.3.2

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
