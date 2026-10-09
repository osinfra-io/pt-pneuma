# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  agentgateway_hostname = "agentgateway.${module.core_helpers.env == "prod" ? "osinfra.io" : "${module.core_helpers.env}.osinfra.io"}"

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.sandbox_authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.sandbox_authentication_stages : key => stage.id
  }

  # One logical Authentik service: the bootstrap token and public base URL are created once in
  # the main workspace and shared by every regional instance, so this workspace configures the
  # provider/application/outpost a single time per environment.
  authentik_token = local.main.authentik_secret_env["AUTHENTIK_BOOTSTRAP_TOKEN"]

  authentik_url = local.main.authentik_base_url

  browser_group_policy_bindings = merge({
    for host in distinct([for item in local.browser_group_policy_items : item.host]) : host => {
      groups = distinct(flatten([
        for item in local.browser_group_policy_items :
        item.host == host ? item.groups : []
      ]))
      host = host
    }
    }, module.core_helpers.environment == "sandbox" ? {
    "https://${local.agentgateway_hostname}" = {
      groups = ["${module.core_helpers.team}: agentgateway Admins"]
      host   = "https://${local.agentgateway_hostname}"
    }
  } : {})

  browser_group_policy_conflicting_hosts = [
    for host in sort(distinct([for item in local.browser_group_policy_items : item.host])) : host
    if length(distinct([
      for item in local.browser_group_policy_items : item.requirements
      if item.host == host
    ])) > 1
  ]

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
            requirements = jsonencode({
              required_groups = sort(try(policy.required_groups, []))
              required_roles  = sort(try(policy.required_roles, []))
            })
          }
          if try(policy.mode, "browser") == "browser" && length(concat(
            try(policy.required_groups, []),
            try(policy.required_roles, []),
          )) > 0
        ]
      ]
    ])
  ])

  default_authentication_source_uuids = []

  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  dns_zone = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => one(keys(try(local.main.gateway_dns[cluster_config.team_key], {})))
  }

  dns_zone_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"

  # The protected gateway host used as the proxy provider external host for forward-auth.
  external_host = "https://${local.dns_zone_name}"

  google_oauth_enabled = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""

  # Keep the shared stage managed while Google is disabled so an apply removes only the Google
  # source. Remove its state address before setting this false.
  manage_default_authentication_stage = true

  # Main workspace outputs (shared Authentik base URL and secret env).
  main = data.terraform_remote_state.main.outputs

  namespace = local.main.authentik_kubernetes_namespace

  # Authentik matches REGEX entries with Python re.fullmatch. The optional hostname prefix
  # accepts the apex and zonal subdomains, but never paths or attacker-controlled hostnames.
  redirect_uris = concat([
    {
      matching_mode = "regex"
      url           = "https://([a-z0-9-]+\\.)*${replace(local.dns_zone_name, ".", "\\.")}/outpost\\.goauthentik\\.io/callback.*"
    }
    ], module.core_helpers.environment == "sandbox" ? [{
      matching_mode = "strict"
      url           = "https://${local.agentgateway_hostname}/outpost.goauthentik.io/callback"
  }] : [])

  sandbox_brand_domain = "authentik.sb.osinfra.io"
  sandbox_brand_title  = "osinfra.io | Sandbox"
  sandbox_flow_title   = "Welcome to osinfra.io sandbox!"
}
