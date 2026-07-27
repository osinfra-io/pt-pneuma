# Output Values
# https://opentofu.org/docs/language/values/outputs

output "namespace" {
  description = "OAuth2 Proxy namespaces by cluster"

  value = {
    for cluster_name, oauth2_proxy in module.kubernetes_oauth2_proxy :
    cluster_name => oauth2_proxy.namespace
  }
}

output "service_name" {
  description = "OAuth2 Proxy Service names by cluster"

  value = {
    for cluster_name, oauth2_proxy in module.kubernetes_oauth2_proxy :
    cluster_name => oauth2_proxy.service_name
  }
}

output "service_port" {
  description = "OAuth2 Proxy Service ports by cluster"

  value = {
    for cluster_name, oauth2_proxy in module.kubernetes_oauth2_proxy :
    cluster_name => oauth2_proxy.service_port
  }
}
