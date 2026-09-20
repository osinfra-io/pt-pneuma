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

  default_authentication_source_uuids = []

  default_authentication_stage_settings = {
    captcha_stage             = null
    case_insensitive_matching = true
    enable_remember_me        = false
    enrollment_flow           = null
    password_stage            = null
    passwordless_flow         = null
    pretend_user_exists       = true
    recovery_flow             = null
    show_matched_user         = true
    show_source_labels        = false
    user_fields               = ["email", "username"]
    webauthn_stage            = null
  }

  google_oauth_enabled = var.google_oauth_client_id != "" && var.google_oauth_client_secret != ""

  # Keep the shared stage managed while Google is disabled so an apply removes only the Google
  # source. Remove its state address before setting this false.
  manage_default_authentication_stage = true

  # Main workspace outputs (shared Authentik base URL and secret env).
  main = data.terraform_remote_state.main.outputs

  namespace = local.main.authentik_kubernetes_namespace

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

  sandbox_authentication_enabled = module.core_helpers.env == "sb"

  sandbox_authentication_stages = {
    identification = {
      name  = "default-authentication-identification"
      order = 10
    }
    login = {
      name  = "default-authentication-login"
      order = 100
    }
    mfa_validation = {
      name        = "default-authentication-mfa-validation"
      order       = 30
      policy_name = "default-authentication-flow-authenticator-validate-stage"
    }
    password = {
      name        = "default-authentication-password"
      order       = 20
      policy_name = "default-authentication-flow-password-stage"
    }
  }

  sandbox_authentication_stage_policies = {
    for key, stage in local.sandbox_authentication_stages : key => stage
    if try(stage.policy_name, null) != null
  }

  sandbox_brand_attributes = jsonencode({
    settings = {
      theme = {
        base = "dark"
      }
    }
  })

  sandbox_brand_custom_css = <<-EOT
    :root {
      --ak-c-login--BackgroundColorOverlay: rgba(30, 30, 30, 0.94);
      --ak-c-login__main--BackgroundColor: #232323;
      --ak-c-login__main--Color: #e0e0e0;
      --pf-global--BackgroundColor--100: #1e1e1e;
      --pf-global--BackgroundColor--200: #232323;
      --pf-global--Color--100: #e0e0e0;
      --pf-global--Color--200: #a0a0a0;
      --pf-global--primary-color--100: #ffb400;
      --pf-global--primary-color--200: #e6a200;
      --pf-c-form-control--BackgroundColor: #2b2b2b;
      --pf-c-form-control--after--BorderBottomColor: #484848;
      --pf-c-form-control--focus--after--BorderBottomColor: #606060;
      --pf-c-form-control--hover--after--BorderBottomColor: #606060;
      --pf-c-form-control--m-expanded--after--BorderBottomColor: #606060;
    }

    ::selection {
      background-color: #484848;
      color: #ffffff;
    }

    .pf-c-background-image {
      background-color: #1e1e1e !important;
      background-image: none !important;
    }

    .pf-c-login__main {
      border: 1px solid #353535;
      border-radius: 8px;
    }

    input,
    textarea,
    select {
      background-color: #2b2b2b !important;
      border-color: #484848 !important;
      color: #e0e0e0 !important;
    }

    input:focus,
    input:focus-visible,
    textarea:focus,
    textarea:focus-visible,
    select:focus,
    select:focus-visible {
      background-color: #303030 !important;
      border-color: #606060 !important;
      box-shadow: inset 0 -2px 0 #606060 !important;
      outline-color: #606060 !important;
    }

    input:autofill,
    input:-webkit-autofill,
    input:-webkit-autofill:focus,
    input:-webkit-autofill:hover {
      -webkit-text-fill-color: #e0e0e0 !important;
      box-shadow: inset 0 0 0 1000px #303030 !important;
      caret-color: #e0e0e0;
    }

    .pf-c-button.pf-m-primary {
      background-color: #ffb400;
      color: #1e1e1e;
    }

    .pf-c-button.pf-m-primary:hover {
      background-color: #e6a200;
    }

    #ak-back-home {
      background-color: #ffb400 !important;
      color: #1e1e1e !important;
    }

    #ak-back-home:active,
    #ak-back-home:focus,
    #ak-back-home:hover {
      background-color: #e6a200 !important;
      color: #1e1e1e !important;
    }

    a {
      color: #ffb400;
    }
  EOT

  sandbox_brand_domain  = "authentik.sb.osinfra.io"
  sandbox_brand_favicon = "https://docs.osinfra.io/img/mirko-transparent.png"
  sandbox_brand_logo    = "https://docs.osinfra.io/img/osinfra-logo-full.png"
  sandbox_brand_title   = "osinfra.io | Sandbox"

  sandbox_flow_title = "Welcome to osinfra.io sandbox!"
}
