# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  source            = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=74a5f1d8a4436cd558007a2fee34ce029c052b13" # v0.2.1
}
