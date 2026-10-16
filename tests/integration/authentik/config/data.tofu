# Authentik Expression Policy
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/policy_expression

data "authentik_policy_expression" "authentication_stage_policies" {
  for_each = module.authentication.authentication_stage_policies

  name = each.value.policy_name
}

# Authentik Stage
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/stage

data "authentik_stage" "authentication_stages" {
  for_each = module.authentication.authentication_stages

  name = each.value.name
}

data "authentik_stage" "default_authentication" {
  name = module.authentik_config.default_authentication_identification_stage_name
}
