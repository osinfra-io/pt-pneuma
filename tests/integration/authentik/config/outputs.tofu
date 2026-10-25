# Output Values
# https://opentofu.org/docs/language/values/outputs

output "authentication" {
  description = "Shared authentication configuration exercised by the local fixture"
  value       = module.authentication
}

output "openbao_client_id" {
  description = "Local OpenBao OIDC client ID"
  value       = module.authentik_config.openbao_client_id
}

output "openbao_client_secret" {
  description = "Local OpenBao OIDC client secret"
  sensitive   = true
  value       = module.authentik_config.openbao_client_secret
}

output "openbao_issuer_url" {
  description = "Local OpenBao OIDC issuer URL"
  value       = module.authentik_config.openbao_issuer_url
}
