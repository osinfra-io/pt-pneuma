# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager//regional?ref=6d8932f1f50f2688a2132feab870c9fef3b4e709" # v0.1.7
}
