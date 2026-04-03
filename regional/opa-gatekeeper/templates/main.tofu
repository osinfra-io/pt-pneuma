# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=972702ba5b89a5c8553bbf67afc715b4188a7712" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR
}
