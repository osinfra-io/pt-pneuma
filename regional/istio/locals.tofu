# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Gateway DNS per cluster, built from the owning team's gateway DNS zones in the
  # main workspace. Keyed by cluster, then by the cluster's zonal subdomain
  # (e.g. "us-east1-b.pneuma.osinfra.io").
  gateway_dns = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for dns_zone, attrs in try(local.main.gateway_dns[cluster_config.team_key], {}) :
      "${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${dns_zone}" => attrs
    }
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Multi-cluster service links per cluster — the set of the owning team's clusters
  # (across all zones) that participate in the Istio multi-cluster mesh.
  multi_cluster_service_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => [
      for peer_name, peer_config in local.main.gke_clusters :
      {
        link = "${regex("(us-[a-z0-9]+)-[a-z]$", peer_name)[0]}/${peer_name}"
      }
      if peer_config.team_key == cluster_config.team_key
    ]
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
