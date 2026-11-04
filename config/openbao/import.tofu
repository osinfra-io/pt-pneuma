# Import
# https://opentofu.org/docs/language/import

import {
  id = "github-actions"
  to = vault_jwt_auth_backend.github_actions
}

import {
  for_each = local.github_actions_roles

  id = each.value.import_id
  to = vault_jwt_auth_backend_role.github_actions[each.key]
}

import {
  for_each = local.github_actions_roles

  id = each.value.policy_name
  to = vault_policy.github_actions[each.key]
}
