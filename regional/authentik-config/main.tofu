# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=b264aa90c1c82d2d463678bdac73c45af7415db1" # v0.1.1

  authentik_url                 = local.authentik_url
  browser_group_policy_bindings = local.browser_group_policy_bindings
  external_host                 = local.external_host
  namespace                     = local.namespace
  redirect_uris                 = local.redirect_uris
}
