# Terraform Remote State Data Source - Authentik
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "authentik" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = module.core_helpers.repository
  }

  workspace = "${local.zone}-authentik-${module.core_helpers.environment}"
}
