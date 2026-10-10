module "team_access" {
  source = "../../../gateway-auth/team-access"

  environment = module.core_helpers.environment
  teams       = module.core_helpers.teams
}

module "gateway_auth" {
  source = "../../../gateway-auth"

  for_each = local.gateway_clusters

  application_group_members = module.team_access.application_group_members
  extension_provider_name   = local.authentik_extension_provider_name
  outpost_namespace         = local.authentik_namespace
  policies                  = local.gateway_auth_browser_policy_inputs[each.key]
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

output "application_group_members" {
  description = "Current environment's managed access passed to the shared renderer."
  value       = module.team_access.application_group_members
}

output "application_access_filters" {
  description = "Production cluster-keyed post-auth guard manifests."
  value       = local.gateway_auth_application_access_filter_manifests
}

output "platform_routes" {
  description = "Dedicated platform hostname routes."
  value       = local.routes
}

output "admin_allow" {
  description = "Cloud admin ingress exception."
  value       = local.agentgateway_admin_allow_manifest
}

output "admin_deny" {
  description = "Cloud admin bypass denial."
  value       = local.agentgateway_admin_deny_manifest
}

output "controller_allow" {
  description = "Proxy-to-controller discovery exception."
  value       = local.agentgateway_controller_allow_manifest
}
