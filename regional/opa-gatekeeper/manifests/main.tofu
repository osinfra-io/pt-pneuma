# Kubernetes OPA Gatekeeper Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/manifests?ref=9d62c3e1b458b2c0dc79b071c6fdf48b1faad02f" # branch: add-block-ingress-policy — update to v0.2.5 post-merge SHA before merging this PR

  gatekeeper_constraints = local.gatekeeper_constraints
}
