# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=58493500e2ea279d4a7b0d35cf95c7b7a83a3e04" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR
}
