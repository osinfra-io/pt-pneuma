# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=a5063665fcb457bdbcd051e85f84171a948296e9" # PR #5

  authentik_url                 = local.authentik_url
  browser_group_policy_bindings = local.browser_group_policy_bindings
  external_host                 = local.external_host
  namespace                     = local.namespace
  redirect_uris                 = local.redirect_uris
}
