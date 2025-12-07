# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "project_id" {
  description = "The Kubernetes project ID"
  value       = length(data.google_project.kubernetes) > 0 ? data.google_project.kubernetes[0].project_id : "${module.helpers.team}-k8s-${module.helpers.env}"
}

output "project_number" {
  description = "The Kubernetes project number"
  value       = length(data.google_project.kubernetes) > 0 ? data.google_project.kubernetes[0].number : null
}
