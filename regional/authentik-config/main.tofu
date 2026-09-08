# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=d877a5f4d9aed392d00b242cfcc037cd859b8783" # testing: osinfra-io/pt-arche-kubernetes-authentik#7 (add-google-oauth-source)

  authentik_url                 = local.authentik_url
  browser_group_policy_bindings = local.browser_group_policy_bindings
  external_host                 = local.external_host
  google_oauth_client_id        = local.google_oauth_client_id
  google_oauth_client_secret    = local.google_oauth_client_secret
  namespace                     = local.namespace
  redirect_uris                 = local.redirect_uris
}
