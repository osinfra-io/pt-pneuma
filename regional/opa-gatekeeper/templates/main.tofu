# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=554b1426f057874b3e92eaba348fd7d8d9580b4f" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR

  gatekeeper_constraints = local.gatekeeper_constraints
}
