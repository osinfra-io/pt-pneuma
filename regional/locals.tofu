# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  gke_cluster_info = {
    for cluster_name, cluster in module.google_kubernetes_engine_regional :
    cluster_name => {
      ca_certificate = cluster.container_cluster_ca_certificate
      endpoint       = cluster.container_cluster_endpoint
      id             = cluster.container_cluster_id
      name           = cluster.container_cluster_name
    }
  }

  # GKE clusters for this specific region-zone — includes all teams deploying to this zone
  # For the fleet host cluster, enrich with gke_hub_memberships; member clusters get an empty map
  # enable_gateway_api is true for every cluster: each hosts its own ambient east-west Gateway.
  gke_clusters = {
    for cluster_name, cluster_config in local.main.gke_clusters :
    cluster_name => merge(cluster_config, {
      enable_gateway_api          = true
      enable_gke_hub_host         = lookup(cluster_config, "enable_gke_hub_host", false)
      gke_hub_memberships         = lookup(cluster_config, "enable_gke_hub_host", false) ? local.gke_hub_memberships : {}
      node_pools                  = lookup(cluster_config, "node_pools", {})
      private_endpoint_subnetwork = "${cluster_name}-master"
    })
    if endswith(cluster_name, "-${module.core_helpers.region}-${module.core_helpers.zone}")
  }

  # GKE Hub memberships - for fleet host cluster, build memberships for all other clusters
  # Cluster IDs follow format: projects/{project}/locations/{location}/clusters/{cluster-name}
  # Extracts region from cluster name suffix (e.g. "us-east1" from "pt-pneuma-us-east1-b")
  gke_hub_memberships = {
    for cluster_name, cluster_config in local.main.gke_clusters :
    cluster_name => {
      cluster_id = "projects/${cluster_config.project_id}/locations/${regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]}/clusters/${cluster_name}"
    }
    if cluster_name != local.subnet && try(local.main.gke_clusters[local.subnet].enable_gke_hub_host, false)
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # Subnet name constructed from team, region, and zone
  subnet = "${module.core_helpers.team}-${module.core_helpers.region}-${module.core_helpers.zone}"
}
