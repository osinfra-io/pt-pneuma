# Kubernetes OPA Gatekeeper Templates Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_templates" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/templates?ref=e34c54dd4bfc05993cfd809a08aa186d73b7db83" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR
}
