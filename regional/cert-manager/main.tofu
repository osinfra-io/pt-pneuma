# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=68551c85ecbfc8f82c313cc3fc7d9335f313d12a" # v0.3.4

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
