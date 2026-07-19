# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager_istio_csr" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional/istio-csr?ref=68551c85ecbfc8f82c313cc3fc7d9335f313d12a" # v0.3.4

  for_each = local.gke_clusters

  providers = {
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  cluster_prefix                              = each.value.team_key
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
