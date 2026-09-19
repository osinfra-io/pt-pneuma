# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=e9c07aa4d013db7eed42bb2c30aaeade3fb87ff6" # v0.1.2

  authentik_url                         = local.authentik_url
  browser_group_policy_bindings         = local.browser_group_policy_bindings
  default_authentication_source_uuids   = local.default_authentication_source_uuids
  default_authentication_stage_settings = local.default_authentication_stage_settings
  external_host                         = local.external_host
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = local.manage_default_authentication_stage
  namespace                             = local.namespace
  redirect_uris                         = local.redirect_uris
}
