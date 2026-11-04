# Terraform Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket
    prefix = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}

# Authentik Brand Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/brand

data "authentik_brand" "built_in" {
  domain = module.authentication.built_in_brand_domain
}

# Authentik Outpost Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/outpost

data "authentik_outpost" "embedded" {
  name = module.authentik_config.embedded_outpost_name
}

# Authentik Expression Policy Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/policy_expression

data "authentik_policy_expression" "authentication_stage_policies" {
  for_each = module.authentication.authentication_stage_policies

  name = each.value.policy_name
}

# Authentik Stage Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/stage

data "authentik_stage" "default_authentication_identification" {
  for_each = local.manage_default_authentication_stage ? toset(["default"]) : toset([])

  name = module.authentik_config.default_authentication_identification_stage_name
}

data "authentik_stage" "authentication_stages" {
  for_each = module.authentication.authentication_stages

  name = each.value.name
}
