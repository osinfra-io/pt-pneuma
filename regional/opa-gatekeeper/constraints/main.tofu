# Kubernetes OPA Gatekeeper Constraints Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_constraints" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/constraints?ref=4371b892347470e29a7e0de993bbe25175c0ec1e" # branch: add-block-ingress-policy — update to post-merge SHA before merging this PR
}
