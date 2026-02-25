# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager_istio_csr" {
  # source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager//regional/istio-csr?ref=6d8932f1f50f2688a2132feab870c9fef3b4e709" # v0.1.7
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager//regional/istio-csr?ref=bump"

  artifact_registry                           = "us-docker.pkg.dev/pt-lz-services-prod/pt-docker-virtual"
  cluster_prefix                              = "pt-pneuma"
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
