# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.helpers.environment)

  # The base production DNS zone name for this team, sourced from team config in pt-logos
  # Falls back to deriving from team name when public_dns_zone_name is not set
  dns_zone_name = lookup(module.helpers.teams[module.helpers.team], "public_dns_zone_name", null) != null ? module.helpers.teams[module.helpers.team].public_dns_zone_name : "${replace(module.helpers.team, "/^[a-z]+-/", "")}.osinfra.io"

  # Gateway DNS configuration for Istio
  # Constructs DNS zone information for the team's public DNS zone created in pt-corpus
  gateway_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (module.helpers.env == "prod" ? local.dns_zone_name : "${module.helpers.env}.${local.dns_zone_name}") = {
      managed_zone = module.helpers.env == "prod" ? replace(local.dns_zone_name, ".", "-") : "${module.helpers.env}-${replace(local.dns_zone_name, ".", "-")}"
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}

  # GKE clusters aggregated from all teams
  gke_clusters = merge([
    for team_key, team in module.helpers.teams :
    lookup(team, "google_kubernetes_engine_clusters", {})
  ]...)
}
