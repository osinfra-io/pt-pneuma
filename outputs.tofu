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

output "debug_pt_corpus_folder_numeric" {
  description = "Debug: Numeric folder ID for pt-corpus"
  value       = local.debug_pt_corpus_folder_numeric
}

output "debug_shared_vpc_filter" {
  description = "Debug: Filter string used for shared VPC host query"
  value       = local.debug_shared_vpc_filter
}

output "debug_shared_vpc_projects_count" {
  description = "Debug: Number of projects found by filter"
  value       = local.debug_shared_vpc_projects_count
}

output "debug_shared_vpc_projects_list" {
  description = "Debug: All projects returned by filter"
  value       = local.debug_shared_vpc_projects_list
}
