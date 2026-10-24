# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentik_config = data.terraform_remote_state.authentik_config.outputs

  main = data.terraform_remote_state.main.outputs

  openbao_group_keys = [
    "openbao-secret-admins",
    "openbao-secret-readers",
    "openbao-secret-writers",
  ]

  openbao_groups = merge({}, [
    for team_key, team in module.core_helpers.teams : {
      for group_key, group in try(team.authentik_groups, {}) : "${team_key}/${group_key}" => {
        access     = trimprefix(group_key, "openbao-secret-")
        group_name = group.name != null ? group.name : "${team_key}: ${group.label}"
        team_key   = team_key
      }
      if contains(local.openbao_group_keys, group_key)
    }
  ]...)

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  team_policy_documents = {
    for key, paths in local.team_policy_paths : key => join("\n\n", [
      for path in paths : format(
        "path \"%s\" {\n  capabilities = %s\n}",
        path.path,
        jsonencode(path.capabilities),
      )
    ])
  }

  team_policy_paths = {
    for key, group in local.openbao_groups : key => concat(
      [
        {
          capabilities = group.access == "readers" ? ["read"] : group.access == "writers" ? ["create", "read", "update"] : ["create", "delete", "read", "update"]
          path         = "team-kv/data/${group.team_key}/*"
        },
        {
          capabilities = group.access == "admins" ? ["create", "delete", "list", "read", "update"] : ["list", "read"]
          path         = "team-kv/metadata/${group.team_key}/*"
        },
        {
          capabilities = ["list", "read"]
          path         = "team-kv/metadata/${group.team_key}"
        },
      ],
      group.access == "admins" ? [
        {
          capabilities = ["update"]
          path         = "team-kv/delete/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "team-kv/destroy/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "team-kv/undelete/${group.team_key}/*"
        },
      ] : [],
    )
  }
}
