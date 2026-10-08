output "env" {
  description = "Mock sandbox environment"
  value       = var.env
}

output "environment" {
  description = "Mock long environment name"
  value       = local.environments[var.env]
}

output "repository" {
  description = "Mock same-repository state discovery"
  value       = "pt-pneuma"
}

output "team" {
  description = "Mock owning platform team"
  value       = "pt-pneuma"
}

output "teams" {
  description = "Mock team naming inputs"
  value = {
    pt-pneuma = {
      dns_subdomain = "pneuma"
    }
  }
}
