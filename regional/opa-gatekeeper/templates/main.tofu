# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=ae79bd1df6439ed15baf769063ffbe7f6bb5f4c6" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR
}
