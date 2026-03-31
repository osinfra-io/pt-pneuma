# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  gatekeeper_constraints = merge([
    for team_key, team in module.core_helpers.teams :
    try(team.google_kubernetes_engine_clusters.gatekeeper_constraints, {})
  ]...)
}
