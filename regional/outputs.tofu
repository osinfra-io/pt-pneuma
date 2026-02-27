# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE cluster information"
  sensitive   = true

  value = {
    for cluster_name, cluster in module.kubernetes_engine_regional :
    cluster_name => {
      ca_certificate = cluster.container_cluster_ca_certificate
      endpoint       = cluster.container_cluster_endpoint
      id             = cluster.container_cluster_id
      name           = cluster.container_cluster_name
    }
  }
}
