# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=3028d24c2bff8e9cfd6e0237c45e99337a0cfc98" # v0.3.5

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
