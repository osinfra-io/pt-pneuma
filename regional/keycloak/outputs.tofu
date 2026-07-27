# Output Values
# https://opentofu.org/docs/language/values/outputs

output "issuer_url" {
  description = "Keycloak issuer URLs by cluster"

  value = {
    for cluster_name, keycloak in module.kubernetes_keycloak :
    cluster_name => keycloak.issuer_url
  }
}

output "jwks_uri" {
  description = "Keycloak JWKS URIs by cluster"

  value = {
    for cluster_name, keycloak in module.kubernetes_keycloak :
    cluster_name => keycloak.jwks_uri
  }
}
