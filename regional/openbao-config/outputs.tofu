# Output Values
# https://opentofu.org/docs/language/values/outputs

output "oidc_auth_mount_path" {
  description = "Path of the OpenBao OIDC authentication mount"
  value       = vault_jwt_auth_backend.oidc.path
}

output "team_kv_mount_path" {
  description = "Path of the team-scoped KV v2 mount"
  value       = vault_mount.team_kv.path
}
