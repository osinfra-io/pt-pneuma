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

resource "vault_jwt_auth_backend" "github_actions" {
  bound_issuer       = "https://token.actions.githubusercontent.com"
  oidc_discovery_url = "https://token.actions.githubusercontent.com"
  path               = "github-actions"

  tune {
    listing_visibility = "hidden"
  }

  type = "jwt"
}

resource "vault_jwt_auth_backend" "oidc" {
  default_role       = "default"
  oidc_client_id     = local.authentik_config.openbao_oidc_client_id
  oidc_client_secret = local.authentik_config.openbao_oidc_client_secret
  oidc_discovery_url = local.authentik_config.openbao_oidc_issuer
  path               = "oidc"

  tune {
    listing_visibility = "unauth"
  }

  type = "oidc"
}

# OpenBao JWT Authentication Backend Role Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/jwt_auth_backend_role

resource "vault_jwt_auth_backend_role" "github_actions" {
  for_each = local.github_actions_roles

  backend                = vault_jwt_auth_backend.github_actions.path
  bound_audiences        = ["pt-pneuma-openbao"]
  bound_claims           = local.github_actions_bound_claims
  bound_claims_type      = "glob"
  bound_subject          = each.value.subject
  role_name              = each.value.policy_name
  role_type              = "jwt"
  token_explicit_max_ttl = 900
  token_max_ttl          = 900
  token_policies         = [vault_policy.github_actions[each.key].name]
  token_ttl              = 900
  user_claim             = "sub"
}

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

resource "vault_mount" "team_kv2" {
  options = {
    version = "2"
  }

  path = "team-kv2"
  type = "kv"
}

# OpenBao Policy Resource
# https://search.opentofu.org/provider/hashicorp/vault/latest/docs/resources/policy

resource "vault_policy" "github_actions" {
  for_each = local.github_actions_roles

  name   = each.value.policy_name
  policy = each.value.policy
}

resource "vault_policy" "team" {
  depends_on = [vault_mount.team_kv2]
  for_each   = local.team_policy_documents

  name   = replace(each.key, "/", "-")
  policy = each.value
}
