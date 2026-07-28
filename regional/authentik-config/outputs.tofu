# Output Values
# https://opentofu.org/docs/language/values/outputs

output "issuer_url" {
  description = "Authentik OIDC issuer URL for the gateway application"
  value       = module.authentik_config.issuer_url
}

output "jwks_uri" {
  description = "Authentik OIDC JWKS URI for the gateway application"
  value       = module.authentik_config.jwks_uri
}

output "outpost_namespace" {
  description = "Namespace of the managed proxy outpost serving Istio ext_authz forward-auth"
  value       = module.authentik_config.outpost_namespace
}

output "outpost_service_name" {
  description = "Service name of the managed proxy outpost for the Istio ext_authz ExtensionProvider"
  value       = module.authentik_config.outpost_service_name
}

output "outpost_service_port" {
  description = "Service port of the managed proxy outpost for the Istio ext_authz ExtensionProvider"
  value       = module.authentik_config.outpost_service_port
}
