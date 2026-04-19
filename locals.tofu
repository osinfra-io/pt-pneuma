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

  # The DNS subdomain for this team (e.g., "pneuma"), sourced from team config in pt-logos
  dns_subdomain = module.core_helpers.teams[module.core_helpers.team].dns_subdomain != null ? module.core_helpers.teams[module.core_helpers.team].dns_subdomain : replace(module.core_helpers.team, "/^[a-z]+-/", "")

  # The team DNS zone name and managed zone resource name, following env-first naming convention
  # prod: pneuma.osinfra.io / pneuma-osinfra-io
  # sb:   pneuma.sb.osinfra.io / pneuma-sb-osinfra-io
  dns_zone_dns_name = module.core_helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io" : "${local.dns_subdomain}.${module.core_helpers.env}.osinfra.io"
  dns_zone_name     = module.core_helpers.env == "prod" ? "${local.dns_subdomain}-osinfra-io" : "${local.dns_subdomain}-${module.core_helpers.env}-osinfra-io"

  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.core_helpers.environment)

  # Gateway DNS configuration for Istio
  # Constructs DNS zone information for the team's public DNS zone created in pt-corpus
  gateway_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (local.dns_zone_dns_name) = {
      managed_zone = local.dns_zone_name
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}

  # GKE clusters aggregated from all teams, filtered by active zones for this environment
  # Derives cluster name as {team_key}-{location} from the flat locations map in pt-logos
  # Merges project_id for each team so regional workspaces can construct correct cluster resource IDs
  gke_clusters = merge([
    for team_key, team in local.teams_with_clusters : {
      for location, config in team.platform_managed_project.kubernetes_engine_locations :
      "${team_key}-${location}" => merge(config, {
        project_id = length(data.google_projects.team_platform_managed[team_key].projects) > 0 ? data.google_projects.team_platform_managed[team_key].projects[0].project_id : error("No platform-managed project found for team '${team_key}'; ensure pt-corpus has provisioned the platform-managed project with labels.repository=pt-corpus and labels.team=${team_key}")
        team_key   = team_key
      })
      if contains(local.active_zones[module.core_helpers.environment], location)
    }
  ]...)

  # Teams with kubernetes clusters configured — used as the for_each key for team_platform_managed data source
  teams_with_clusters = {
    for team_key, team in module.core_helpers.teams :
    team_key => team
    if length(team.platform_managed_project.kubernetes_engine_locations) > 0
  }
}
