# Output Values
# https://opentofu.org/docs/language/values/outputs

output "namespace" {
  description = "Authentik namespaces by cluster in this zone"

  value = {
    for cluster_name, authentik in module.kubernetes_authentik :
    cluster_name => authentik.namespace
  }
}
