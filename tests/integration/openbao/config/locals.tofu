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

  team_keys = toset([
    "pt-arche",
    "pt-corpus",
    "pt-ekklesia",
    "pt-logos",
    "pt-pneuma",
    "pt-techne",
    "st-ethos",
  ])

  team_readme_content = <<-EOT
    # OpenBao team secrets

    Set the local OpenBao endpoint and trust the local gateway certificate before signing in:

    ```bash
    export BAO_ADDR=https://openbao.localhost
    export BAO_CACERT="$PWD/tests/integration/istio/.work/gateway-localhost.crt"
    bao login -method=oidc -path=oidc role=default
    ```

    Your team prefix is `<team-key>`. List team prefixes, list your secrets, and read this guide with:

    ```bash
    bao kv list kv2
    bao kv list kv2/<team-key>
    bao kv get kv2/<team-key>/README
    ```

    Create or update a secret under your team prefix with:

    ```bash
    bao kv put kv2/<team-key>/my-secret example=value
    ```

    Team access is granted through the `openbao-secret-readers`, `openbao-secret-writers`,
    and `openbao-secret-admins` groups. Readers can list and read; writers can create and update;
    admins can also manage secret metadata and versions. Do not store credentials in source
    repositories or CI settings.
  EOT

  team_readme_contents = {
    for team_key in local.team_keys : team_key => replace(
      local.team_readme_content,
      "<team-key>",
      team_key,
    )
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
          capabilities = ["list"]
          path         = "kv2/metadata"
        },
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
