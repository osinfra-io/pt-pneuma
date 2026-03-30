# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager_istio_csr" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional/istio-csr?ref=ed05c50c5bb9c7213e32d8601780fe604585c049" # v0.2.4

  artifact_registry                           = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  cluster_prefix                              = module.core_helpers.team
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
