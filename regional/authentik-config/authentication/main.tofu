# Authentik Brand
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand

resource "authentik_brand" "sandbox" {
  for_each = local.instances

  attributes          = local.brand_attributes
  branding_custom_css = local.brand_custom_css_api
  branding_favicon    = "https://docs.osinfra.io/img/mirko-transparent.png"
  branding_logo       = "https://docs.osinfra.io/img/osinfra-logo-full.png"
  branding_title      = var.brand_title
  default             = false
  domain              = var.brand_domain
  flow_authentication = authentik_flow.sandbox_authentication[each.key].uuid
}

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

resource "authentik_flow" "sandbox_authentication" {
  for_each = local.instances

  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = var.flow_title
  slug               = "sandbox-authentication-flow"
  title              = var.flow_title
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "sandbox_authentication_stages" {
  for_each = local.enabled_stages

  evaluate_on_plan     = false
  order                = each.value.order
  re_evaluate_policies = true
  stage                = var.stage_ids[each.key]
  target               = authentik_flow.sandbox_authentication["sandbox"].uuid
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "sandbox_authentication_stage_policies" {
  for_each = local.enabled_stage_policies

  failure_result = true
  order          = 10
  policy         = var.policy_ids[each.key]
  target         = authentik_flow_stage_binding.sandbox_authentication_stages[each.key].id
}
