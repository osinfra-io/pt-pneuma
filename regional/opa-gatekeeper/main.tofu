# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=ae40aea9c3e163f5b22cdb3044a0c4e775af2d61" # v0.2.1

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.helpers.team}-virtual"
}
