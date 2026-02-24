# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Environment key for logos lookup (title case with hyphens preserved)
  # Converts workspace environment (e.g., "non-production") to logos format (e.g., "Non-Production")
  environment_key = title(module.helpers.environment)

  # GKE clusters aggregated from all teams
  gke_clusters = merge([
    for team_key, team in module.helpers.teams :
    lookup(team, "google_kubernetes_engine_clusters", {})
  ]...)

  # Gateway DNS configuration for Istio
  # Constructs DNS zone information for the team's public DNS zone
  # Zone is created in pt-corpus and follows pattern: {env}.{team_name}.osinfra.io (or {team_name}.osinfra.io for prod)
  gateway_dns = length(data.google_projects.shared_vpc_host.projects) > 0 ? {
    (module.helpers.env == "prod" ? "${replace(module.helpers.team, "/^[a-z]+-/", "")}.osinfra.io" : "${module.helpers.env}.${replace(module.helpers.team, "/^[a-z]+-/", "")}.osinfra.io") = {
      managed_zone = module.helpers.env == "prod" ? "${replace(module.helpers.team, "/^[a-z]+-/", "")}-osinfra-io" : "${module.helpers.env}-${replace(module.helpers.team, "/^[a-z]+-/", "")}-osinfra-io"
      project      = data.google_project.shared_vpc_host.project_id
    }
  } : {}
}
