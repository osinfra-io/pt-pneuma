path "sys/auth" {
  capabilities = ["read"]
}

path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/auth/oidc" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

path "sys/auth/oidc/*" {
  capabilities = ["read", "update", "sudo"]
}

path "sys/mounts/auth/oidc" {
  capabilities = ["read"]
}

path "sys/mounts/auth/oidc/tune" {
  capabilities = ["read", "update"]
}

path "sys/auth/github-actions" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

path "sys/auth/github-actions/*" {
  capabilities = ["read", "update", "sudo"]
}

path "sys/mounts/auth/github-actions" {
  capabilities = ["read"]
}

path "sys/mounts/auth/github-actions/tune" {
  capabilities = ["read", "update"]
}

path "auth/github-actions/config" {
  capabilities = ["read", "update"]
}

path "auth/github-actions/role/pt-pneuma-openbao-*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "auth/oidc/config" {
  capabilities = ["read", "update"]
}

path "auth/oidc/role/default" {
  capabilities = ["create", "read", "update", "delete"]
}

path "sys/mounts/team-kv2" {
  capabilities = ["read"]
}

path "sys/mounts/kv2" {
  capabilities = ["create", "read", "update", "delete", "sudo"]
}

path "sys/mounts/kv2/*" {
  capabilities = ["read", "update"]
}

path "sys/remount" {
  capabilities = ["update", "sudo"]

  allowed_parameters = {
    "from" = ["team-kv2", "team-kv2/"]
    "to"   = ["kv2", "kv2/"]
  }
}

path "sys/remount/status/*" {
  capabilities = ["read"]
}

path "sys/policies/acl/pt-pneuma-openbao-*" {
  capabilities = ["create", "read", "update", "delete"]
}

path "identity/group" {
  capabilities = ["create", "update"]
}

path "identity/group/id/*" {
  capabilities = ["read", "update", "delete"]
}

path "identity/group-alias" {
  capabilities = ["create", "update"]
}

path "identity/group-alias/id/*" {
  capabilities = ["read", "update", "delete"]
}

path "auth/token/create" {
  capabilities = ["update"]
}
