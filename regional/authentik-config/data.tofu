# Terraform Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}

# Authentik Outpost Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/outpost

data "authentik_outpost" "embedded" {
  name = module.authentik_config.embedded_outpost_name
}

# Authentik Stage Data Source
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/data-sources/stage

data "authentik_stage" "default_authentication_identification" {
  name = module.authentik_config.default_authentication_identification_stage_name
}
