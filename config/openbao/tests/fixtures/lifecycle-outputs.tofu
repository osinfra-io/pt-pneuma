variable "previous_apply_policy" {
  default     = null
  description = "Apply ACL from the preceding lifecycle run"
  type        = string
}

variable "previous_team_resource_keys" {
  default     = {}
  description = "Applied team resource keys from the preceding lifecycle run"
  type        = map(list(string))
}

output "apply_policy" {
  description = "Applied workflow ACL for comparison across lifecycle runs"
  value       = vault_policy.github_actions["apply"].policy
}

output "team_resource_keys" {
  description = "Applied team aliases, groups, and policies for lifecycle assertions"
  value = {
    aliases  = keys(vault_identity_group_alias.team)
    groups   = keys(vault_identity_group.team)
    policies = keys(vault_policy.team)
  }
}
