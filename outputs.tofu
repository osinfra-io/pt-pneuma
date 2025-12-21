# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "project_id" {
  description = "The Kubernetes project ID"
  value       = data.google_project.kubernetes[0].project_id
}

output "project_number" {
  description = "The Kubernetes project number"
  value       = data.google_project.kubernetes[0].number
}

output "team" {
  description = "The team data from helpers module"
  value       = module.helpers.teams[module.helpers.team]
}
