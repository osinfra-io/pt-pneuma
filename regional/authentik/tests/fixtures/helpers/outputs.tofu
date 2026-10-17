locals {
  environments = {
    non-production = "nonprod"
    production     = "prod"
    sandbox        = "sb"
  }
}

variable "environment" {
  description = "Mock environment name"
  type        = string
}

output "env" {
  description = "Mock short environment name"
  value       = local.environments[var.environment]
}

output "environment" {
  description = "Mock environment name"
  value       = var.environment
}

output "repository" {
  description = "Mock same-repository state discovery"
  value       = "pt-pneuma"
}

output "team" {
  description = "Mock owning platform team"
  value       = "pt-pneuma"
}
