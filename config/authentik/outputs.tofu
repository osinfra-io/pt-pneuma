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

output "openbao_oidc_client_id" {
  description = "The OAuth2 client ID for OpenBao"
  value       = module.authentik_config.openbao_client_id
}

output "openbao_oidc_client_secret" {
  description = "The sensitive OAuth2 client secret for OpenBao"
  sensitive   = true
  value       = module.authentik_config.openbao_client_secret
}

output "openbao_oidc_issuer" {
  description = "The provider-specific Authentik OIDC issuer URL for OpenBao"
  value       = module.authentik_config.openbao_issuer_url
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

output "pending_application_members" {
  description = "Declared application members awaiting verified Google enrollment, keyed by stable team/group identifiers."
  sensitive   = true
  value       = module.authentik_config.pending_application_members
}
