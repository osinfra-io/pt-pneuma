# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters aggregated from all teams
  gke_clusters = merge([
    for team_key, team in module.helpers.teams :
    lookup(team, "google_kubernetes_engine_clusters", {})
  ]...)
}
