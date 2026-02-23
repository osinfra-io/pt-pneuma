# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "kubernetes_engine_workload_identity_service_account_emails" {
  description = "The email addresses of the service accounts for the Kubernetes namespace workload identity"
  value       = module.kubernetes_engine.workload_identity_service_account_emails
}

output "project_id" {
  description = "The Kubernetes project ID"
  value       = data.google_project.kubernetes.project_id
}

output "project_number" {
  description = "The Kubernetes project number"
  value       = data.google_project.kubernetes.number
}

output "shared_vpc_host_project_id" {
  description = "The shared VPC host project ID from pt-corpus"
  value       = data.google_project.shared_vpc_host.project_id
}

output "team" {
  description = "The team data from helpers module"
  value       = module.helpers.teams[module.helpers.team]
}
