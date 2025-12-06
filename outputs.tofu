# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "project_id" {
  description = "The Kubernetes project ID from pt-corpus"
  value       = data.terraform_remote_state.corpus.outputs.teams["pt-pneuma"].kubernetes_project.id
}

output "project_number" {
  description = "The Kubernetes project number from pt-corpus"
  value       = data.terraform_remote_state.corpus.outputs.teams["pt-pneuma"].kubernetes_project.number
}
