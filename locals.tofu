# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Active zones per environment — controls which GKE clusters are included in outputs
  # Sandbox and non-production use 2 zones (1 per region) for multi-cluster testing
  # Production uses all 6 zones (3 per region) for full HA

  active_zones = {
    non-production = toset(["us-east1-b", "us-east4-a"])
    production     = toset(["us-east1-b", "us-east1-c", "us-east1-d", "us-east4-a", "us-east4-b", "us-east4-c"])
    sandbox        = toset(["us-east1-b", "us-east4-a"])
  }

  # DNS subdomain per team (e.g., "pneuma"), sourced from team config in pt-logos.
  # Falls back to the team key with its topology prefix stripped (e.g. "pt-pneuma" → "pneuma").
  dns_subdomains = {
    for team_key, team in local.teams_with_clusters :
    team_key => team.dns_subdomain != null ? team.dns_subdomain : replace(team_key, "/^[a-z]+-/", "")
  }

  # Team DNS zone DNS name per team, following env-first naming convention
  # prod: pneuma.osinfra.io   sb: pneuma.sb.osinfra.io
  dns_zone_dns_names = {
    for team_key, subdomain in local.dns_subdomains :
    team_key => module.core_helpers.env == "prod" ? "${subdomain}.osinfra.io" : "${subdomain}.${module.core_helpers.env}.osinfra.io"
  }

  # Team managed zone resource name per team, following env-first naming convention
  # prod: pneuma-osinfra-io   sb: pneuma-sb-osinfra-io
  dns_zone_names = {
    for team_key, subdomain in local.dns_subdomains :
    team_key => module.core_helpers.env == "prod" ? "${subdomain}-osinfra-io" : "${subdomain}-${module.core_helpers.env}-osinfra-io"
  }

  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.core_helpers.environment)

  # Gateway DNS configuration for Istio per team
  # Constructs DNS zone information for each team's public DNS zone created in pt-corpus
  gateway_dns_by_team = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => length(data.google_projects.shared_vpc_host.projects) > 0 ? {
      (local.dns_zone_dns_names[team_key]) = {
        managed_zone = local.dns_zone_names[team_key]
        project      = data.google_project.shared_vpc_host.project_id
      }
    } : {}
  }

  # GKE clusters aggregated from all teams, filtered by active zones for this environment
  # Derives cluster name as {team_key}-{location} from the flat locations map in pt-logos
  # Merges project_id for each team so regional workspaces can construct correct cluster resource IDs
  gke_clusters = merge([
    for team_key, team in local.teams_with_clusters : {
      for location, config in team.platform_managed_project.kubernetes_engine_locations :
      "${team_key}-${location}" => merge(config, {
        project_id = local.team_project_ids[team_key]
        team_key   = team_key
      })
      if contains(local.active_zones[module.core_helpers.environment], location)
    }
  ]...)

  # GKE namespaces per team, derived from Logos team data.
  # pt-pneuma provisions every team's declared namespaces in that team's own clusters.
  gke_namespaces_by_team = {
    for team_key, team in local.teams_with_clusters :
    team_key => try(team.platform_managed_project.kubernetes_engine_namespaces, {})
  }

  # Platform-managed project ID per team, discovered from pt-corpus labels.
  team_project_ids = {
    for team_key in keys(local.teams_with_clusters) :
    team_key => length(data.google_projects.team_platform_managed[team_key].projects) > 0 ? data.google_projects.team_platform_managed[team_key].projects[0].project_id : error("No platform-managed project found for team '${team_key}'; ensure pt-corpus has provisioned the platform-managed project with labels.repository=pt-corpus and labels.team=${team_key}")
  }

  # Teams with kubernetes clusters configured — used as the for_each key for team_platform_managed data source
  teams_with_clusters = {
    for team_key, team in module.core_helpers.teams :
    team_key => team
    if length(team.platform_managed_project.kubernetes_engine_locations) > 0
  }
}
