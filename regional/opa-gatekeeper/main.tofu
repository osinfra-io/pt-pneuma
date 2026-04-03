# Kubernetes Open Policy Agent Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional?ref=4371b892347470e29a7e0de993bbe25175c0ec1e" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
}
