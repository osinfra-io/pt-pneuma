# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager_istio_csr" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager//regional/istio-csr?ref=a0f6efd73e0d807358290fab35309c1ae9299a77" # v0.2.0

  artifact_registry                           = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.helpers.team}-virtual"
  cluster_prefix                              = module.helpers.team
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
