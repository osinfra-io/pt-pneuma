# Output Values
# https://opentofu.org/docs/language/values/outputs

output "base_url" {
  description = "Authentik base URLs by cluster (public OIDC issuer/provider host)"

  value = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => local.authentik_base_url
  }
}

output "bootstrap_token" {
  description = "Authentik bootstrap API tokens by cluster, used by the authentik-config workspace to configure the provider"
  sensitive   = true

  value = {
    for cluster_name in keys(local.authentik_clusters) :
    cluster_name => random_password.authentik_bootstrap_token[cluster_name].result
  }
}

output "namespace" {
  description = "Authentik namespaces by cluster"

  value = {
    for cluster_name, authentik in module.kubernetes_authentik :
    cluster_name => authentik.namespace
  }
}
