# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=679825a8a8e19921c1674b2dafe58e54b7ae792b" # v0.2.1

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.helpers.team}-virtual"
}
