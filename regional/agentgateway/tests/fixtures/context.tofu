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
