# Authentik Group
# https://search.opentofu.org/provider/goauthentik/authentik/latest/docs/resources/group

resource "authentik_group" "floor_approvers" {
  name = var.approver_group
}

# Authentik Token
# https://search.opentofu.org/provider/goauthentik/authentik/latest/docs/resources/token

# An app password is what the outpost accepts as HTTP Basic credentials.
resource "authentik_token" "floor_verify" {
  identifier   = "floor-verify-app-password"
  intent       = "app_password"
  retrieve_key = true
  user         = tonumber(authentik_user.floor_verify.id)
}

resource "authentik_token" "floor_visitor" {
  identifier   = "floor-visitor-app-password"
  intent       = "app_password"
  retrieve_key = true
  user         = tonumber(authentik_user.floor_visitor.id)
}

# Authentik User
# https://search.opentofu.org/provider/goauthentik/authentik/latest/docs/resources/user

resource "authentik_user" "floor_verify" {
  email    = local.verify_email
  groups   = local.verify_group_ids
  name     = "floor verification"
  username = var.username
}

# The visitor authenticates but holds no approver group, so floor-api must refuse its mutations.
resource "authentik_user" "floor_visitor" {
  email    = local.visitor_email
  groups   = [data.authentik_group.all.id]
  name     = "floor visitor"
  username = var.visitor_username
}

# Local Sensitive File
# https://search.opentofu.org/provider/hashicorp/local/latest/docs/resources/sensitive_file

resource "local_sensitive_file" "verify_token" {
  content         = authentik_token.floor_verify.key
  file_permission = "0600"
  filename        = var.token_file
}

resource "local_sensitive_file" "visitor_token" {
  content         = authentik_token.floor_visitor.key
  file_permission = "0600"
  filename        = var.visitor_token_file
}
