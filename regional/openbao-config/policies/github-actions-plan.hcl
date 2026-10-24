path "sys/auth" {
  capabilities = ["read"]
}

path "sys/mounts" {
  capabilities = ["read"]
}

path "sys/auth/oidc" {
  capabilities = ["read"]
}

path "sys/auth/oidc/*" {
  capabilities = ["read"]
}

path "sys/mounts/auth/oidc/tune" {
  capabilities = ["read"]
}

path "sys/auth/github-actions" {
  capabilities = ["read"]
}

path "sys/auth/github-actions/*" {
  capabilities = ["read"]
}

path "sys/mounts/auth/github-actions/tune" {
  capabilities = ["read"]
}

path "auth/github-actions/config" {
  capabilities = ["read"]
}

path "auth/github-actions/role/pt-pneuma-openbao-*" {
  capabilities = ["read"]
}

path "sys/mounts/team-kv" {
  capabilities = ["read"]
}

path "sys/mounts/team-kv/*" {
  capabilities = ["read"]
}

path "auth/oidc/config" {
  capabilities = ["read"]
}

path "auth/oidc/role/default" {
  capabilities = ["read"]
}

path "sys/policies/acl/pt-pneuma-openbao-*" {
  capabilities = ["read"]
}

path "identity/group/id/*" {
  capabilities = ["read"]
}

path "identity/group-alias/id/*" {
  capabilities = ["read"]
}
