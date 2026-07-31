# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # One logical Authentik service: the bootstrap token and public base URL are created once in
  # the main workspace and shared by every regional instance, so this workspace configures the
  # provider/application/outpost a single time per environment.
  authentik_token = local.main.authentik_secret_env["AUTHENTIK_BOOTSTRAP_TOKEN"]

  authentik_url = local.main.authentik_base_url

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # The protected gateway host used as the proxy provider external host for forward-auth.
  external_host = "https://${local.dns_zone_name}"

  # Main workspace outputs (shared Authentik base URL and secret env).
  main = data.terraform_remote_state.main.outputs

  namespace = "authentik"

  # OAuth2 redirect URIs the gateway is allowed to return to after authentication.
  # Authentik matches REGEX entries with Python re.fullmatch, so the wildcard is restricted to
  # hostname characters (no "/") to prevent an attacker-controlled host/path from satisfying the
  # pattern, and the literal dots in the fixed path are escaped.
  redirect_uris = [
    {
      matching_mode = "regex"
      url           = "https://[a-z0-9.-]+\\.${replace(local.dns_zone_name, ".", "\\.")}/outpost\\.goauthentik\\.io/callback.*"
    }
  ]
}
