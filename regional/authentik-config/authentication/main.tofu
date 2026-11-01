# Authentik Brand
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/brand

# Authentik allows a single default brand. The built-in brand ships as the default, so callers import
# it here and demote it before the osinfra.io brand takes over.
resource "authentik_brand" "built_in" {
  default = false
  domain  = local.built_in_brand_domain
}

resource "authentik_brand" "this" {
  depends_on = [authentik_brand.built_in]

  attributes          = local.brand_attributes
  branding_custom_css = local.brand_custom_css_api
  branding_favicon    = "https://docs.osinfra.io/img/mirko-transparent.png"
  branding_logo       = "https://docs.osinfra.io/img/osinfra-logo-full.png"
  branding_title      = var.brand_title
  default             = true
  domain              = var.brand_domain
  flow_authentication = authentik_flow.authentication.uuid
}

# Authentik Flow
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow

resource "authentik_flow" "authentication" {
  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = var.flow_title
  slug               = "osinfra-authentication-flow"
  title              = var.flow_title
}

# Authentik Flow Stage Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/flow_stage_binding

resource "authentik_flow_stage_binding" "authentication_stages" {
  for_each = local.authentication_stages

  evaluate_on_plan     = false
  order                = each.value.order
  re_evaluate_policies = true
  stage                = var.stage_ids[each.key]
  target               = authentik_flow.authentication.uuid
}

# Authentik Policy Binding
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/policy_binding

resource "authentik_policy_binding" "authentication_stage_policies" {
  for_each = local.authentication_stage_policies

  failure_result = true
  order          = 10
  policy         = var.policy_ids[each.key]
  target         = authentik_flow_stage_binding.authentication_stages[each.key].id
}
