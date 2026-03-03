# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
  main         = data.terraform_remote_state.main.outputs

  gateway_dns = {
    for zone, attrs in local.main.gateway_dns :
    "${module.helpers.region}-${module.helpers.zone}.${zone}" => attrs
  }
}
