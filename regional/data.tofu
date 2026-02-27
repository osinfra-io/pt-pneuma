# OpenTofu Remote State Datasource
# https://opentofu.org/docs/language/state/remote-state-data/

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = module.helpers.repository
  }

  workspace = "main-${module.helpers.environment}"
}
