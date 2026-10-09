module "core_helpers" {
  source = "./helpers"

  environment = var.test_environment
}

variable "test_environment" {
  default     = "sandbox"
  description = "Environment selected by the provider-free cloud workspace regression."
  type        = string
}

output "clusters" {
  description = "Selected agentgateway deployment clusters."
  value       = local.agentgateway_clusters
}

output "namespace" {
  description = "Owning team's namespace."
  value       = local.namespace
}

output "admin_allow" {
  description = "Cloud admin ingress exception."
  value       = local.admin_allow_manifest
}

output "admin_deny" {
  description = "Cloud admin bypass denial."
  value       = local.admin_authorization_manifest
}
