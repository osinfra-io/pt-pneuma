output "authentication" {
  description = "Authentication rendered by the actual cloud root"
  value       = module.authentication
}

output "pending_application_members" {
  description = "Pending identities exposed by the pinned cloud configuration module."
  sensitive   = true
  value       = module.authentik_config.pending_application_members
}

output "cloud_inputs" {
  description = "Resolved cloud inputs independent of the extracted brand/flow resources"
  value = {
    default_authentication_source_uuids = local.default_authentication_source_uuids
    external_host                       = local.external_host
    manage_default_authentication_stage = local.manage_default_authentication_stage
    namespace                           = local.namespace
    redirect_uris                       = local.redirect_uris
  }
}
