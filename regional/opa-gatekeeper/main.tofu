# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=44943f9fb606715b1fc688c4a746b931afb7ab39" # v0.2.0

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.helpers.team}-virtual"
}
