# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "project_id" {
  description = "The Kubernetes project ID"
  value       = data.google_project.kubernetes.project_id
}

output "project_number" {
  description = "The Kubernetes project number"
  value       = data.google_project.kubernetes.number
}
