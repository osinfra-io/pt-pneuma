# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE cluster information"
  sensitive   = true
  value       = local.gke_cluster_info
}
