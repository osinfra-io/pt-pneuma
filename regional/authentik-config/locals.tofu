# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # One logical Authentik service: the bootstrap token and public base URL are created once in
  # the main workspace and shared by every regional instance, so this workspace configures the
  # provider/application/outpost a single time per environment.
  authentik_token = local.main.authentik_secret_env["AUTHENTIK_BOOTSTRAP_TOKEN"]

  authentik_url = local.main.authentik_base_url

  browser_group_policy_bindings = {
    for host in distinct([for item in local.browser_group_policy_items : item.host]) : host => {
      groups = distinct(flatten([
        for item in local.browser_group_policy_items :
        item.host == host ? item.groups : []
      ]))
      host = host
    }
  }

  browser_group_policy_items = flatten([
    for cluster_name, cluster_config in var.clusters : flatten([
      for ns_name, ns in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) : [
        for route_name, policy in try(ns.route_auth_policies, {}) : [
          for host in [
            "https://${local.dns_zone[cluster_name]}",
            "https://${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${local.dns_zone[cluster_name]}",
            ] : {
            groups = distinct(concat(
              try(policy.required_groups, []),
              try(policy.required_roles, []),
            ))
            host = host
          }
          if try(policy.mode, "browser") == "browser" && length(concat(
            try(policy.required_groups, []),
            try(policy.required_roles, []),
          )) > 0
        ]
      ]
    ])
  ])

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => one(keys(try(local.main.gateway_dns[cluster_config.team_key], {})))
  }

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # The protected gateway host used as the proxy provider external host for forward-auth.
  external_host = "https://${local.dns_zone_name}"

  # Main workspace outputs (shared Authentik base URL and secret env).
  main = data.terraform_remote_state.main.outputs

  namespace = "authentik"

  # OAuth2 redirect URIs the gateway is allowed to return to after authentication.
  # Authentik matches REGEX entries with Python re.fullmatch. The subdomain prefix is optional so
  # both the zone apex (the configured external_host) and zonal subdomains are accepted, but each
  # label is restricted to hostname characters (no "/", "@" or extra dots) so an attacker-controlled
  # host/path cannot satisfy the pattern; the literal dots in the fixed path are escaped.
  redirect_uris = [
    {
      matching_mode = "regex"
      url           = "https://([a-z0-9-]+\\.)*${replace(local.dns_zone_name, ".", "\\.")}/outpost\\.goauthentik\\.io/callback.*"
    }
  ]
}
