# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name = "${module.helpers.team}-${local.region}-${local.zone}"
  main         = data.terraform_remote_state.main.outputs
  region       = substr(terraform.workspace, 0, 8)
  zone         = regex("[a-z]$", terraform.workspace)
}
