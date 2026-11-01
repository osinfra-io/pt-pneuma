output "authentication" {
  description = "Authentication rendered by the actual cloud root"
  value       = module.authentication
}

output "cloud_inputs" {
  description = "Resolved cloud inputs independent of the extracted brand/flow resources"
  value = {
    default_authentication_source_uuids = local.default_authentication_source_uuids
    dns_zone_name                       = local.dns_zone_name
    manage_default_authentication_stage = local.manage_default_authentication_stage
    namespace                           = local.namespace
    redirect_uris                       = local.redirect_uris
  }
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

output "pending_application_members" {
  description = "Pending identities exposed by the pinned cloud configuration module."
  sensitive   = true
  value       = module.authentik_config.pending_application_members
}
