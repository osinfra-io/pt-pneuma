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

  # Debug: Shared VPC Host Discovery
  debug_pt_corpus_folder_id       = module.helpers.teams["pt-corpus"].environments[local.environment_key]
  debug_pt_corpus_folder_numeric  = replace(module.helpers.teams["pt-corpus"].environments[local.environment_key], "folders/", "")
  debug_shared_vpc_filter         = "parent.id:${replace(module.helpers.teams["pt-corpus"].environments[local.environment_key], "folders/", "")} labels.repository:pt-corpus labels.team:pt-corpus lifecycleState:ACTIVE"
  debug_shared_vpc_projects_count = length(data.google_projects.shared_vpc_host.projects)

  debug_shared_vpc_projects_list = [
    for p in data.google_projects.shared_vpc_host.projects : {
      id     = p.project_id
      labels = p.labels
      name   = p.name
      parent = p.parent.id
    }
  ]
}
