# Kubernetes OPA Gatekeeper Constraints Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper

module "kubernetes_opa_gatekeeper_constraints" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-opa-gatekeeper//regional/constraints?ref=94ef92f7eaec4a0365ec249fb312a24914e1e7cb" # v0.5.1

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  allowed_groups       = local.gateway_auth_guardrail_allowed_groups
  allowed_users        = local.gateway_auth_guardrail_allowed_users
  protected_kinds      = local.gateway_auth_guardrail_protected_kinds
  protected_namespaces = local.gateway_auth_guardrail_protected_namespaces
}
