# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=d7d4a636cd6db76b4d1edf064a7bcfa1358e9b6e" # PR #5

  authentik_url                 = local.authentik_url
  browser_group_policy_bindings = local.browser_group_policy_bindings
  external_host                 = local.external_host
  namespace                     = local.namespace
  redirect_uris                 = local.redirect_uris
}
