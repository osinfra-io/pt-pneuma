# Output Values
# https://opentofu.org/docs/language/values/outputs

output "callback_routes" {
  description = "Browser host callback routes in the regional/manifests routes input shape."
  value       = local.callback_routes
}

output "custom_authorization_policy_manifests" {
  description = "Browser-only CUSTOM AuthorizationPolicy manifests, retaining stable input map keys."
  value       = local.custom_authorization_policy_manifests
}

output "extension_provider" {
  description = "Fail-closed Authentik HTTP extension provider for meshConfig.extensionProviders."
  value       = local.extension_provider
}

output "inbound_header_strip_filter_manifest" {
  description = "Gateway EnvoyFilter stripping client x-authentik-* headers before ext_authz."
  value       = local.inbound_header_strip_filter_manifest
}

output "resolved_policies" {
  description = "Policies with stable names and shared path exemptions; API JWT claim intent is preserved but no JWT resources are rendered."
  value       = local.resolved_policies
}
