# Output Values
# https://opentofu.org/docs/language/values/outputs

# Debug outputs for troubleshooting filters
output "debug_kubernetes_projects_found" {
  description = "List of project IDs found by kubernetes filter"
  value       = [for p in data.google_projects.kubernetes.projects : p.project_id]
}

output "debug_shared_vpc_projects_found" {
  description = "List of project IDs found by shared VPC filter"
  value       = [for p in data.google_projects.shared_vpc_host.projects : p.project_id]
}

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
