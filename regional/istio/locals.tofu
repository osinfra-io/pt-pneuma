# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name = "${module.core_helpers.team}-${module.core_helpers.region}-${module.core_helpers.zone}"

  gateway_dns = {
    for zone, attrs in local.main.gateway_dns :
    "${module.core_helpers.region}-${module.core_helpers.zone}.${zone}" => attrs
  }

  main = data.terraform_remote_state.main.outputs

  multi_cluster_service_clusters = [
    for cluster_key, cluster_config in local.main.gke_clusters : {
      link = "${regex("^${module.core_helpers.team}-(us-[a-z0-9]+)-[a-z]$", cluster_key)[0]}/${cluster_key}"
    }
  ]
}
