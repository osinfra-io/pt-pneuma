# Output Values
# https://opentofu.org/docs/language/values/outputs

output "authentication_stage_policies" {
  description = "Built-in expression policy discovery names keyed by stage"
  value       = local.authentication_stage_policies
}

output "authentication_stages" {
  description = "Built-in stage discovery names and binding order keyed by stage"
  value       = local.authentication_stages
}

output "brands" {
  description = "Managed authentication brands keyed by the preserved cloud instance key"
  value       = authentik_brand.sandbox
}

output "default_authentication_stage_settings" {
  description = "Identification settings shared by the default and custom authentication flows"
  value       = local.default_authentication_stage_settings
}

output "flows" {
  description = "Managed custom authentication flows keyed by the preserved cloud instance key"
  value       = authentik_flow.sandbox_authentication
}

output "policy_bindings" {
  description = "Conditional authentication policy bindings keyed by stage"
  value       = authentik_policy_binding.sandbox_authentication_stage_policies
}

output "stage_bindings" {
  description = "Authentication stage bindings keyed by stage"
  value       = authentik_flow_stage_binding.sandbox_authentication_stages
}
