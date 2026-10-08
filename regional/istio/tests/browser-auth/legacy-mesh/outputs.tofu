module "gateway_auth" {
  source = "../../../gateway-auth"

  for_each = local.gateway_clusters

  extension_provider_name = local.authentik_extension_provider_name
  outpost_namespace       = local.authentik_resolved_outpost_namespace
  outpost_path_prefix     = local.authentik_outpost_path_prefix
  outpost_service_name    = local.authentik_resolved_outpost_service_name
  outpost_service_port    = local.authentik_resolved_outpost_service_port
}

output "extension_providers" {
  description = "Production extension-provider rendering."
  value       = local.istio_mesh_config_extension_providers
}
