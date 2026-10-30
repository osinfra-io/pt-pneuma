# Kubernetes Authentik
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "../../../../../../arche/pt-arche-kubernetes-authentik/regional/config"

  application_launch_url = "https://dev.localhost/istio-test/auth"
  application_groups     = local.application_groups
  application_name       = "Development"
  application_slug       = "development-oidc"
  authentik_url          = "https://authentik.localhost"

  browser_group_policy_bindings = {
    agentgateway = {
      groups     = ["pt-pneuma: agentgateway Admins"]
      host       = "https://agentgateway.localhost"
      icon       = "https://docs.osinfra.io/img/applications/agentgateway.svg"
      launch_url = "https://agentgateway.localhost/ui/"
      name       = "agentgateway"
    }
    development = {
      groups     = ["all"]
      host       = "https://dev.localhost"
      icon       = "https://docs.osinfra.io/img/applications/istio.svg"
      launch_url = "https://dev.localhost/istio-test/auth"
      name       = "Istio"
    }
  }

  client_id = "development"

  default_authentication_stage_settings = module.authentication.default_authentication_stage_settings
  external_host                         = "https://dev.localhost"
  gateway_oidc_enabled                  = false
  google_internal_domains               = ["osinfra.io"]
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = true
  namespace                             = "authentik"
  openbao_application_icon              = "https://docs.osinfra.io/img/applications/openbao.svg"
  openbao_hostname                      = "openbao.localhost"
  outpost_authentik_url                 = "https://authentik.localhost"
  superuser_group_keys                  = ["pt-pneuma/authentik-admins"]

  redirect_uris = [
    {
      matching_mode = "strict"
      url           = "https://dev.localhost/oauth2/callback"
    },
  ]
}

# Pneuma Authentication
# https://github.com/osinfra-io/pt-pneuma

module "authentication" {
  source = "../../../../regional/authentik-config/authentication"

  brand_domain = "authentik.localhost"
  brand_title  = "osinfra.io | Development"
  flow_title   = "Welcome to osinfra.io development!"
  policy_ids   = local.authentication_policy_ids
  stage_ids    = local.authentication_stage_ids
}

# Logos Application Access
# https://github.com/osinfra-io/pt-pneuma

module "team_access" {
  source = "../../../../regional/istio/gateway-auth/team-access"

  environment = "sandbox"
  teams       = var.teams
}
