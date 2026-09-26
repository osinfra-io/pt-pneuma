# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=50122dfd99038d0c4e02e48fd175d62f8c6aae6e" # v0.4.0

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
