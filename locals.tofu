# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.helpers.environment)

  # The DNS subdomain for this team (e.g., "pneuma"), sourced from team config in pt-logos
  dns_subdomain = lookup(module.helpers.teams[module.helpers.team], "dns_subdomain", replace(module.helpers.team, "/^[a-z]+-/", ""))

  # The team DNS zone name and managed zone resource name, following env-first naming convention
  # prod: pneuma.osinfra.io / pneuma-osinfra-io
  # sb:   pneuma.sb.osinfra.io / pneuma-sb-osinfra-io
  dns_zone_dns_name = module.helpers.env == "prod" ? "${local.dns_subdomain}.osinfra.io." : "${local.dns_subdomain}.${module.helpers.env}.osinfra.io."
  dns_zone_name     = module.helpers.env == "prod" ? "${local.dns_subdomain}-osinfra-io" : "${local.dns_subdomain}-${module.helpers.env}-osinfra-io"

  # Gateway DNS configuration for Istio
  # Constructs DNS zone information for the team's public DNS zone created in pt-corpus
  gateway_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (local.dns_zone_dns_name) = {
      managed_zone = local.dns_zone_name
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}

  # GKE clusters aggregated from all teams
  gke_clusters = merge([
    for team_key, team in module.helpers.teams :
    lookup(team, "google_kubernetes_engine_clusters", {})
  ]...)
}
