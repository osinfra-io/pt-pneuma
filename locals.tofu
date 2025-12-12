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
}
