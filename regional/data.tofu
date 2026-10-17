# OpenTofu Remote State Datasource
# https://opentofu.org/docs/language/state/remote-state-data/

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket
    prefix = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}
