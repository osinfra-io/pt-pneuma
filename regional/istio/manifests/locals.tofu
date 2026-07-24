# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # DNS subdomain per cluster, extracted from the gateway DNS zone name
  # (e.g. "pneuma.sb.osinfra.io" → "pneuma", "kryptos.sb.osinfra.io" → "kryptos").
  dns_subdomain = {
    for cluster_name in keys(local.gke_clusters) :
    cluster_name => try(split(".", local.dns_zone[cluster_name])[0], "")
  }

  # The single gateway DNS zone for each cluster's owning team (e.g. "pneuma.osinfra.io").
  # one() errors loudly if a team has >1 zone and returns null if empty; both cases
  # indicate the main workspace has not been applied for that team.
  dns_zone = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => one(keys(try(local.main.gateway_dns[cluster_config.team_key], {})))
  }

  # Failover region per cluster (the paired region for multi-region istio failover).
  failover_to_region = {
    for cluster_name in keys(local.gke_clusters) :
    cluster_name => local.regions[cluster_name] == "us-east1" ? "us-east4" : "us-east1"
  }

  # GKE clusters in this zone that have the Istio gateway enabled (platform team only).
  # Used for resources that are gateway-specific (e.g. Datadog AAP EnvoyFilter).
  gateway_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Per-team global (apex) HTTPRoutes derived from each team's Logos-declared namespace routes. Keyed
  # by the team's cluster in this zone. Every route declared under a mesh-enabled namespace becomes an
  # apex HTTPRoute on the team's subdomain ("<subdomain>.osinfra.io"), co-located with its backend
  # Service in the team-prefixed namespace (e.g. "pt-kryptos-istio-test").
  global_routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => merge([
      for ns_name, ns in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) : {
        for route_name, route in try(ns.routes, {}) :
        "${route_name}-${local.dns_subdomain[cluster_name]}" => {
          backend_namespace = "${cluster_config.team_key}-${ns_name}"
          backend_port      = route.port
          backend_service   = route.service
          host              = local.dns_zone[cluster_name]
          path              = route.path
        }
      }
    ]...)
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # HTTPRoutes for the gateway cluster, aggregated across every team present in this zone. Gateway
  # (pneuma) clusters receive HTTPRoutes for ALL teams — all external traffic enters through pneuma's
  # ingress gateway. Non-gateway clusters get nothing (they have no gateway data plane). Each team
  # contributes its global (apex) routes plus their zonal probe siblings; route keys embed the team
  # subdomain to avoid collisions across teams.
  routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key == module.core_helpers.team ? merge([
      for peer_name, peer_config in local.gke_clusters :
      merge(local.global_routes[peer_name], local.zonal_routes[peer_name])
    ]...) : {}
  }

  # Per-team zonal probe HTTPRoutes derived from each team's Logos-declared istio-test routes. Keyed
  # by the team's cluster in this zone. Only the istio-test namespace is scaffolded per zone (a
  # platform test convention); each apex route gets a zonal sibling targeting the per-zone Service
  # ("<service>-<zone>") under the zonal host ("<zone>.<subdomain>.osinfra.io").
  zonal_routes = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for route_name, route in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces["istio-test"].routes, {}) :
      "${route_name}-${local.dns_subdomain[cluster_name]}-${local.zone}" => {
        backend_namespace = "${cluster_config.team_key}-istio-test"
        backend_port      = route.port
        backend_service   = "${route.service}-${local.zone}"
        host              = "${local.zone}.${local.dns_zone[cluster_name]}"
        path              = route.path
      }
    }
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-manifests-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
