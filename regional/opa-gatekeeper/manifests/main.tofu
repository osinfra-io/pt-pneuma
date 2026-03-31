# Kubernetes OPA Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/manifests?ref=1033032e9e7651387d58bca6fc0e03bff3783fcc" # TODO: update to v0.2.5 post-merge SHA before merging this PR

  gatekeeper_constraints = local.gatekeeper_constraints
}
