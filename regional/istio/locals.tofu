# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Gateway DNS per cluster. Pneuma (gateway) clusters create zonal A records for ALL
  # teams — because every team's DNS routes through pneuma's single ingress gateway.
  # Member team clusters get nothing (their traffic arrives via the mesh, not a local LB).
  gateway_dns = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key == module.core_helpers.team ? {
      for team_key, team_dns in local.main.gateway_dns :
      "${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${one(keys(team_dns))}" => one(values(team_dns))
      if length(team_dns) > 0
    } : {}
  }

  # GKE clusters in this zone that have the Istio gateway enabled (platform team only).
  # Used for resources that are gateway-specific (e.g. Datadog AAP extproc).
  gateway_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  # Per-team gateway listeners per cluster. Only pneuma (gateway) clusters carry the
  # per-team listeners — every team's subdomain routes through pneuma's single gateway.
  # Member team clusters run no gateway and get nothing. Empty until a team sets
  # route_prefix, in which case the arche istio module falls back to a from:All listener.
  gateway_listeners = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key == module.core_helpers.team ? local.main.gateway_listeners : {}
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
