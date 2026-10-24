# Terraform Remote State Data Source - Authentik Config
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "authentik_config" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket
    prefix = module.core_helpers.repository
  }

  workspace = "authentik-config-${module.core_helpers.environment}"
}

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
