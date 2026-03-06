# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
  main         = data.terraform_remote_state.main.outputs

  gateway_dns = {
    for zone, attrs in local.main.gateway_dns :
    "${module.helpers.region}-${module.helpers.zone}.${zone}" => attrs
  }

  multi_cluster_service_clusters = [
    for cluster_key, cluster_config in local.main.gke_clusters : {
      link = "${regex("^${module.helpers.team}-(us-[a-z0-9]+)-[a-z]$", cluster_key)[0]}/${cluster_key}"
    }
  ]
}
