# OpenBao Identity Group Alias Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/identity_group_alias

resource "vault_identity_group_alias" "team" {
  for_each = local.openbao_groups

  canonical_id   = vault_identity_group.team[each.key].id
  mount_accessor = vault_jwt_auth_backend.oidc.accessor
  name           = each.value.group_name
}

# OpenBao Identity Group Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/identity_group

resource "vault_identity_group" "team" {
  for_each = local.openbao_groups

  name     = each.value.group_name
  policies = [vault_policy.team[each.key].name]
  type     = "external"
}

# OpenBao JWT Authentication Backend Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/jwt_auth_backend

resource "vault_jwt_auth_backend" "oidc" {
  default_role       = "default"
  oidc_client_id     = local.authentik_config.openbao_oidc_client_id
  oidc_client_secret = local.authentik_config.openbao_oidc_client_secret
  oidc_discovery_url = local.authentik_config.openbao_oidc_issuer
  path               = "oidc"
  type               = "oidc"
}

# OpenBao JWT Authentication Backend Role Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/jwt_auth_backend_role

resource "vault_jwt_auth_backend_role" "oidc" {
  allowed_redirect_uris = [
    "https://${local.main.openbao_hostname}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback",
  ]
  backend         = vault_jwt_auth_backend.oidc.path
  bound_audiences = [local.authentik_config.openbao_oidc_client_id]
  groups_claim    = "groups"
  oidc_scopes     = ["email", "groups", "profile"]
  role_name       = "default"
  role_type       = "oidc"
  token_max_ttl   = 3600
  token_policies  = ["default"]
  token_ttl       = 3600
  user_claim      = "sub"
}

# OpenBao Mount Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/mount

resource "vault_mount" "team_kv" {
  options = {
    version = "2"
  }

  path = "team-kv"
  type = "kv"
}

# OpenBao Policy Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/policy

resource "vault_policy" "team" {
  depends_on = [vault_mount.team_kv]
  for_each   = local.team_policy_documents

  name   = replace(each.key, "/", "-")
  policy = each.value
}
