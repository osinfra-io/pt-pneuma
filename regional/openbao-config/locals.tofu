# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentik_config = data.terraform_remote_state.authentik_config.outputs

  github_actions_apply_policy = join("\n\n", compact([
    file("${path.module}/policies/github-actions-apply.hcl"),
    join("\n\n", [
      for policy_name in local.openbao_policy_names : format(
        "path \"sys/policies/acl/%s\" {\n  capabilities = %s\n}",
        policy_name,
        jsonencode(["create", "read", "update", "delete"]),
      )
    ]),
  ]))

  github_actions_bound_claims = {
    event_name          = module.core_helpers.env == "sb" ? "pull_request" : "push,workflow_dispatch"
    ref                 = module.core_helpers.env == "sb" ? "refs/pull/*/merge" : "refs/heads/main"
    repository_id       = "1093115151"
    repository_owner_id = "104685378"
  }

  github_actions_environment = {
    sb      = "Sandbox"
    nonprod = "Non-Production"
    prod    = "Production"
  }[module.core_helpers.env]

  github_actions_plan_subject = module.core_helpers.env == "sb" ? "repo:osinfra-io/pt-pneuma:pull_request" : "repo:osinfra-io/pt-pneuma:ref:refs/heads/main"

  github_actions_roles = {
    for access in ["apply", "plan"] : access => {
      import_id   = "auth/github-actions/role/pt-pneuma-openbao-${access}"
      policy      = access == "apply" ? local.github_actions_apply_policy : file("${path.module}/policies/github-actions-plan.hcl")
      policy_name = "pt-pneuma-openbao-${access}"
      subject     = access == "apply" ? "repo:osinfra-io/pt-pneuma:environment:${local.github_actions_environment} OpenBao%3A us-east1-b" : local.github_actions_plan_subject
    }
  }

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

  openbao_policy_names = sort(flatten([
    for team_key in keys(module.core_helpers.teams) : [
      for group_key in local.openbao_group_keys : "${team_key}-${group_key}"
    ]
  ]))

  team_readme_content = {
    for team_key in keys(module.core_helpers.teams) : team_key => <<-EOT
      # OpenBao team secrets

      Use the environment's supported OpenBao endpoint and sign in with your Google-backed account:

      ```bash
      export BAO_ADDR=https://${local.main.openbao_hostname}
      bao login -method=oidc -path=oidc role=default
      ```

      Your team prefix is `${team_key}`. Team prefixes are visible to all OpenBao team members, but
      secret data remains restricted to your own team. List team prefixes, list your secrets, and
      read this guide with:

      ```bash
      bao kv list kv2
      bao kv list kv2/${team_key}
      bao kv get kv2/${team_key}/README
      ```

      Create or update a secret under your team prefix with:

      ```bash
      bao kv put kv2/${team_key}/my-secret example=value
      ```

      Team access is granted through the `openbao-secret-readers`, `openbao-secret-writers`,
      and `openbao-secret-admins` groups. Readers can list and read; writers can create and update;
      admins can also manage secret metadata and versions. Do not store credentials in source
      repositories or CI settings.
    EOT
  }

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
