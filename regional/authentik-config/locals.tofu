# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  agentgateway_hostname = "agentgateway.${local.public_dns_domain}"

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.authentication_stages : key => stage.id
  }

  authentik_brand_domain = "authentik.${local.public_dns_domain}"
  authentik_brand_title  = module.core_helpers.env == "prod" ? "osinfra.io" : "osinfra.io | ${title(module.core_helpers.environment)}"
  authentik_flow_title   = module.core_helpers.env == "prod" ? "Welcome to osinfra.io!" : "Welcome to osinfra.io ${module.core_helpers.environment}!"

  # One logical Authentik service: the bootstrap token and public base URL are created once in
  # the main workspace and shared by every regional instance, so this workspace configures the
  # provider/application/outpost a single time per environment.
  authentik_token = local.main.authentik_secret_env["AUTHENTIK_BOOTSTRAP_TOKEN"]

  authentik_url = local.main.authentik_base_url

  authentik_superuser_group_keys = [
    for key in keys(module.team_access.application_groups) :
    key if key == "pt-pneuma/authentik-admins"
  ]

  browser_group_policy_bindings = merge({
    for host in distinct([for item in local.browser_group_policy_items : item.host]) : host => {
      groups = distinct(flatten([
        for item in local.browser_group_policy_items :
        item.host == host ? item.required_groups : []
      ]))
      hidden      = !anytrue([for item in local.browser_group_policy_items : item.global if item.host == host])
      host        = host
      icon        = "https://docs.osinfra.io/img/authentik/applications/istio.svg"
      launch_url  = "${host}/istio-test/auth"
      name        = "Istio"
      policy_name = "${[for item in local.browser_group_policy_items : item.team_key if item.host == host][0]}-browser-access"
      roles = distinct(flatten([
        for item in local.browser_group_policy_items :
        item.host == host ? item.required_roles : []
      ]))
    }
    }, module.core_helpers.environment == "sandbox" ? {
    "https://${local.agentgateway_hostname}" = {
      groups      = ["${module.core_helpers.team}: agentgateway Admins"]
      host        = "https://${local.agentgateway_hostname}"
      policy_name = "agentgateway-browser-access"
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
      for ns in values(try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {})) : [
        for policy in values(try(ns.route_auth_policies, {})) : [
          for host in [
            { global = true, url = "https://${local.dns_zone[cluster_name]}" },
            { global = false, url = "https://${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${local.dns_zone[cluster_name]}" },
            ] : {
            global          = host.global
            host            = host.url
            required_groups = try(policy.required_groups, [])
            required_roles  = try(policy.required_roles, [])
            requirements = jsonencode({
              required_groups = sort(try(policy.required_groups, []))
              required_roles  = sort(try(policy.required_roles, []))
            })
            team_key = cluster_config.team_key
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

  # Main workspace outputs (shared Authentik base URL and secret env).
  main = data.terraform_remote_state.main.outputs

  # Keep the shared stage managed while Google is disabled so an apply removes only the Google
  # source. Remove its state address before setting this false.
  manage_default_authentication_stage = true

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

  # Prod drops the env segment.
  public_dns_domain = module.core_helpers.env == "prod" ? "osinfra.io" : "${module.core_helpers.env}.osinfra.io"

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"
}
