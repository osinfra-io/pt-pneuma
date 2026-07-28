# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # A single gateway Authentik per zonal workspace: take the one deployment's base URL and
  # bootstrap token from the authentik workspace outputs.
  authentik_token = one(values(data.terraform_remote_state.authentik.outputs.bootstrap_token))

  authentik_url = one(values(data.terraform_remote_state.authentik.outputs.base_url))

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # The protected gateway host used as the proxy provider external host for forward-auth.
  external_host = "https://${local.dns_zone_name}"

  namespace = one(values(data.terraform_remote_state.authentik.outputs.namespace))

  # OAuth2 redirect URIs the gateway is allowed to return to after authentication.
  redirect_uris = [
    {
      matching_mode = "regex"
      url           = "https://.*\\.${replace(local.dns_zone_name, ".", "\\.")}/outpost.goauthentik.io/callback.*"
    }
  ]

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-authentik-config-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
