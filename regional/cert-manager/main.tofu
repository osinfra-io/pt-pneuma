# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=639dce2182a01fd6315cb9d1948bec7e967b7b2c" # v0.3.7

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
