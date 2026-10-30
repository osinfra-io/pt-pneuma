# Output Values
# https://opentofu.org/docs/language/values/outputs

output "application_group_members" {
  description = "Exact managed group names and selected environment emails for Authentik membership validation."
  value       = local.application_group_members
}

output "application_groups" {
  description = "Stable team/group identifiers consumed by Authentik configuration."
  value       = local.application_groups
}
