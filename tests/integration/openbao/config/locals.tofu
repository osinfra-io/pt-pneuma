# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  openbao_groups = {
    "pt-pneuma/openbao-secret-admins" = {
      access     = "admins"
      group_name = "pt-pneuma: OpenBao Secret Admins"
      team_key   = "pt-pneuma"
    }
    "pt-pneuma/openbao-secret-readers" = {
      access     = "readers"
      group_name = "pt-pneuma: OpenBao Secret Readers"
      team_key   = "pt-pneuma"
    }
    "pt-pneuma/openbao-secret-writers" = {
      access     = "writers"
      group_name = "pt-pneuma: OpenBao Secret Writers"
      team_key   = "pt-pneuma"
    }
  }

  team_policy_documents = {
    for key, paths in local.team_policy_paths : key => join("\n\n", [
      for path in paths : format(
        "path \"%s\" {\n  capabilities = %s\n}",
        path.path,
        jsonencode(path.capabilities),
      )
    ])
  }

  team_policy_names = {
    for key in keys(local.openbao_groups) : key => replace(key, "/", "-")
  }

  team_policy_paths = {
    for key, group in local.openbao_groups : key => concat(
      [
        {
          capabilities = group.access == "readers" ? ["read"] : group.access == "writers" ? ["create", "read", "update"] : ["create", "delete", "read", "update"]
          path         = "kv2/data/${group.team_key}/*"
        },
        {
          capabilities = group.access == "admins" ? ["create", "delete", "list", "read", "update"] : ["list", "read"]
          path         = "kv2/metadata/${group.team_key}/*"
        },
        {
          capabilities = ["list", "read"]
          path         = "kv2/metadata/${group.team_key}"
        },
      ],
      group.access == "admins" ? [
        {
          capabilities = ["update"]
          path         = "kv2/delete/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "kv2/destroy/${group.team_key}/*"
        },
        {
          capabilities = ["update"]
          path         = "kv2/undelete/${group.team_key}/*"
        },
      ] : [],
    )
  }
}
