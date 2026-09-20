# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=f8da266ff952ef0b4045e1f8272cfc46f4b19850" # v0.3.8

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
