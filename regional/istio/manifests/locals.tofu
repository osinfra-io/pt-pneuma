# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Removed local.kubernetes_project - now using data.terraform_remote_state.main.outputs.project_id directly
}
