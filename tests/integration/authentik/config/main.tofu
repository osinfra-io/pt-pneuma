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
      groups = ["all"]
      host   = "https://agentgateway.localhost"
    }
    development = {
      groups = ["all"]
      host   = "https://dev.localhost"
    }
  }

  client_id = "development"

  default_authentication_stage_settings = module.authentication.default_authentication_stage_settings
  external_host                         = "https://dev.localhost"
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = true
  namespace                             = "authentik"
  openbao_hostname                      = "openbao.localhost"
  outpost_authentik_url                 = "https://authentik.localhost"

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
