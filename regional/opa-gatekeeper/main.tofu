# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=c10448c342bd06093e61ca7122a0fb9450461942" # v0.2.4

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
}
