# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE namespaces for this team, derived from Logos team data.
  # Namespaces are scoped to the current team's own clusters — each team's
  # onboarding workspace creates only that team's declared namespaces.
  gke_namespaces = try(
    module.core_helpers.teams[module.core_helpers.team].platform_managed_project.kubernetes_engine_namespaces,
    {}
  )
}
