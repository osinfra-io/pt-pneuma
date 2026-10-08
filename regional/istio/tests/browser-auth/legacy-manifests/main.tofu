module "gateway_auth" {
  source = "../../../gateway-auth"

  for_each = local.gateway_clusters

  extension_provider_name = local.authentik_extension_provider_name
  outpost_namespace       = local.authentik_namespace
  policies                = local.gateway_auth_browser_policy_inputs[each.key]
}

output "gateway_auth_authorization_policies" {
  description = "Production policy intent and exemptions."
  value       = local.gateway_auth_authorization_policies
}

output "custom_manifests" {
  description = "Production browser CUSTOM policy renderer."
  value       = local.gateway_auth_custom_authorization_policy_manifests
}

output "callback_routes" {
  description = "Production callback route renderer."
  value       = local.authentik_callback_routes
}

output "jwt_manifests" {
  description = "Production API JWT claim enforcement."
  value       = local.gateway_auth_required_claim_authorization_policy_manifests
}
