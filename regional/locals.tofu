# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters filtered for this specific region-zone
  # Each regional workspace only builds the cluster matching its region and zone
  # For fleet host, enrich with gke_hub_memberships
  gke_clusters = {
    for cluster_name, cluster_config in local.main.gke_clusters :
    cluster_name => merge(cluster_config, {
      gke_hub_memberships = local.gke_hub_memberships
    })
    if cluster_name == local.subnet
  }

  # GKE Hub memberships - for fleet host cluster, build memberships for all other clusters
  # Cluster IDs follow format: projects/{project}/locations/{location}/clusters/{cluster-name}
  # Extracts region from cluster name suffix (e.g. "us-east1" from "pt-kryptos-us-east1-b")
  gke_hub_memberships = {
    for cluster_name, cluster_config in local.main.gke_clusters :
    cluster_name => {
      cluster_id = "projects/${cluster_config.project_id}/locations/${regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]}/clusters/${cluster_name}"
    }
    if cluster_name != local.subnet && try(local.main.gke_clusters[local.subnet].enable_gke_hub_host, false)
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Subnet name constructed from team, region, and zone
  subnet = "${module.core_helpers.team}-${module.core_helpers.region}-${module.core_helpers.zone}"
}
