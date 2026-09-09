# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=fd6b949cc2ba1b7e67ea40e426a6fcb82f8a7caf" # testing: osinfra-io/pt-arche-kubernetes-authentik#7 (add-google-oauth-source)

  authentik_url                 = local.authentik_url
  browser_group_policy_bindings = local.browser_group_policy_bindings
  external_host                 = local.external_host
  google_oauth_client_id        = local.google_oauth_client_id
  google_oauth_client_secret    = local.google_oauth_client_secret
  namespace                     = local.namespace
  redirect_uris                 = local.redirect_uris
}
