# Kubernetes Authentik Config Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "authentik_config" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional/config?ref=af6e9e6371f216aa61fd710e3f0af6eed5657fcd" # v0.1.8

  depends_on = [terraform_data.browser_group_policy_validation]

  authentik_url                         = local.authentik_url
  browser_group_policy_bindings         = local.browser_group_policy_bindings
  default_authentication_source_uuids   = local.default_authentication_source_uuids
  default_authentication_stage_settings = local.default_authentication_stage_settings
  external_host                         = local.external_host
  google_oauth_client_id                = var.google_oauth_client_id
  google_oauth_client_secret            = var.google_oauth_client_secret
  manage_default_authentication_stage   = local.manage_default_authentication_stage
  namespace                             = local.namespace
  redirect_uris                         = local.redirect_uris
}

# Authentik Brand
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand

resource "authentik_brand" "sandbox" {
  for_each = var.sandbox_authentication_enabled ? toset(["sandbox"]) : toset([])

  attributes          = local.sandbox_brand_attributes
  branding_custom_css = local.sandbox_brand_custom_css
  branding_favicon    = local.sandbox_brand_favicon
  branding_logo       = local.sandbox_brand_logo
  branding_title      = local.sandbox_brand_title
  default             = false
  domain              = local.sandbox_brand_domain
  flow_authentication = authentik_flow.sandbox_authentication[each.key].uuid
}

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

resource "authentik_flow" "sandbox_authentication" {
  for_each = var.sandbox_authentication_enabled ? toset(["sandbox"]) : toset([])

  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = local.sandbox_flow_title
  slug               = "sandbox-authentication-flow"
  title              = local.sandbox_flow_title
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "sandbox_authentication_stages" {
  for_each = var.sandbox_authentication_enabled ? local.sandbox_authentication_stages : {}

  evaluate_on_plan     = false
  order                = each.value.order
  re_evaluate_policies = true
  stage                = data.authentik_stage.sandbox_authentication_stages[each.key].id
  target               = authentik_flow.sandbox_authentication["sandbox"].uuid
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "sandbox_authentication_stage_policies" {
  for_each = var.sandbox_authentication_enabled ? local.sandbox_authentication_stage_policies : {}

  failure_result = true
  order          = 10
  policy         = data.authentik_policy_expression.sandbox_authentication_stage_policies[each.key].id
  target         = authentik_flow_stage_binding.sandbox_authentication_stages[each.key].id
}

# Terraform Data Resource
# https://search.opentofu.org/provider/hashicorp/terraform/latest/docs/resources/data

resource "terraform_data" "browser_group_policy_validation" {
  lifecycle {
    precondition {
      condition     = length(local.browser_group_policy_conflicting_hosts) == 0
      error_message = "Browser routes sharing an Authentik host must declare identical required_groups and required_roles. Conflicting hosts: ${join(", ", local.browser_group_policy_conflicting_hosts)}."
    }
  }
}
