variable "environment" {
  description = "Fixture deployment environment."
  type        = string
}

output "environment" {
  description = "Fixture deployment environment."
  value       = var.environment
}

output "team" {
  description = "Fixture owning team."
  value       = "pt-pneuma"
}
