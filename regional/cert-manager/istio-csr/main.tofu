# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager_istio_csr" {
  artifact_registry                           = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  cluster_prefix                              = module.core_helpers.team
  source                                      = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional/istio-csr?ref=51b9c4ce4933a31870c9ea5fd398f96d7674232f" # v0.2.2
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
