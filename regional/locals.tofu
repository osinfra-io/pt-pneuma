# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters filtered for this specific region-zone
  # Each regional workspace only builds the cluster matching its region and zone
  gke_clusters = {
    for cluster_name, cluster_config in local.main.gke_clusters :
    cluster_name => cluster_config
    if cluster_name == local.subnet
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Subnet name constructed from team, region, and zone
  subnet = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
}
