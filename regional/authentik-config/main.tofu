# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=d508fb2884f62e77ce16e09db5ea9ba624e03ff8" # testing: osinfra-io/pt-arche-kubernetes-authentik#7 (add-google-oauth-source)

  authentik_url                         = local.authentik_url
  browser_group_policy_bindings         = local.browser_group_policy_bindings
  default_authentication_source_uuids   = local.default_authentication_source_uuids
  default_authentication_stage_settings = local.default_authentication_stage_settings
  external_host                         = local.external_host
  google_oauth_client_id                = local.google_oauth_client_id
  google_oauth_client_secret            = local.google_oauth_client_secret
  manage_default_authentication_stage   = local.manage_default_authentication_stage
  namespace                             = local.namespace
  redirect_uris                         = local.redirect_uris
}
