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

output "brand" {
  description = "Managed authentication brand"
  value       = authentik_brand.this
}

output "built_in_brand_domain" {
  description = "Domain of the built-in Authentik brand that callers import"
  value       = local.built_in_brand_domain
}

output "default_authentication_stage_settings" {
  description = "Identification settings shared by the default and custom authentication flows"
  value       = local.default_authentication_stage_settings
}

output "flow" {
  description = "Managed custom authentication flow"
  value       = authentik_flow.authentication
}

output "policy_bindings" {
  description = "Conditional authentication policy bindings keyed by stage"
  value       = authentik_policy_binding.authentication_stage_policies
}

output "stage_bindings" {
  description = "Authentication stage bindings keyed by stage"
  value       = authentik_flow_stage_binding.authentication_stages
}
