# Output Values
# https://opentofu.org/docs/language/values/outputs

output "gke_clusters" {
  description = "GKE cluster information"
  value = {
    for cluster_name, cluster in module.kubernetes_engine_regional :
    cluster_name => {
      ca_certificate = cluster.ca_certificate
      endpoint       = cluster.endpoint
      id             = cluster.id
      name           = cluster.name
    }
  }
  sensitive = true
}
