# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  source            = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=51b9c4ce4933a31870c9ea5fd398f96d7674232f" # v0.2.2
}
