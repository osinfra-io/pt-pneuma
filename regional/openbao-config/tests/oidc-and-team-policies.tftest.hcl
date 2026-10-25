mock_provider "vault" {}

override_data {
  target = data.terraform_remote_state.authentik_config
  values = {
    outputs = {
      openbao_oidc_client_id     = "openbao"
      openbao_oidc_client_secret = "mock-client-secret"
      openbao_oidc_issuer        = "https://authentik.example/application/o/openbao/"
    }
  }
}

override_data {
  target = data.terraform_remote_state.main
  values = {
    outputs = {
      openbao_hostname = "openbao.example"
    }
  }
}

override_module {
  target = module.core_helpers
  outputs = {
    env         = "sb"
    environment = "sandbox"
    repository  = "pt-pneuma"
    team        = "pt-pneuma"
    teams = {
      pt-example = {
        authentik_groups = {
          openbao-secret-admins = {
            label = "OpenBao Secret Admins"
            name  = "pt-example: OpenBao Secret Admins"
          }
          openbao-secret-readers = {
            label = "OpenBao Secret Readers"
            name  = "pt-example: OpenBao Secret Readers"
          }
          openbao-secret-writers = {
            label = "OpenBao Secret Writers"
            name  = "pt-example: OpenBao Secret Writers"
          }
        }
      }
      pt-other = {
        authentik_groups = {
          openbao-secret-readers = {
            label = "OpenBao Secret Readers"
            name  = "pt-other: OpenBao Secret Readers"
          }
        }
      }
    }
  }
}

variables {
  openbao_address = "https://openbao.example"
}

run "reader_is_limited_to_read_and_list" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "path \"kv2/data/pt-example/*\"") &&
      strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "\"read\"") &&
      strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "\"list\"") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "\"create\"") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "\"delete\"")
    )
    error_message = "Readers must only read and list secrets inside their own team prefix."
  }
}

run "writer_cannot_delete_or_manage_versions" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "\"create\"") &&
      strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "\"update\"") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "\"delete\"") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "kv2/delete/") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "kv2/undelete/") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "kv2/destroy/")
    )
    error_message = "Writers must create and update without deleting data, metadata, or versions."
  }
}

run "admin_and_all_roles_stay_inside_team_prefix" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "kv2/data/pt-example/*") &&
      strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "kv2/metadata/pt-example/*") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "pt-other") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "sys/")
    )
    error_message = "Admin policy must manage only pt-example secrets and must not grant system access."
  }

  assert {
    condition = alltrue([
      for key, group in local.openbao_groups :
      alltrue([
        for other_team_key in keys(module.core_helpers.teams) :
        group.team_key == other_team_key || !strcontains(local.team_policy_documents[key], other_team_key)
        ]) && alltrue([
        for path in local.team_policy_paths[key] :
        contains([
          "kv2/data/${group.team_key}/*",
          "kv2/metadata/${group.team_key}/*",
          "kv2/metadata/${group.team_key}",
          "kv2/delete/${group.team_key}/*",
          "kv2/destroy/${group.team_key}/*",
          "kv2/undelete/${group.team_key}/*",
        ], path.path)
      ]) && !strcontains(local.team_policy_documents[key], "sys/")
    ])
    error_message = "Every policy must stay on its owner's team-key paths and exclude other teams and OpenBao system endpoints."
  }
}

run "oidc_uses_group_claim_and_exact_callbacks_without_team_token_policies" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      try(one(vault_jwt_auth_backend.oidc.tune).listing_visibility, null) == "unauth" &&
      try(one(vault_jwt_auth_backend.github_actions.tune).listing_visibility, null) == "hidden"
    )
    error_message = "The login page must advertise OIDC without advertising GitHub Actions authentication."
  }

  assert {
    condition = (
      vault_jwt_auth_backend.oidc.oidc_client_id == "openbao" &&
      vault_jwt_auth_backend.oidc.oidc_discovery_url == "https://authentik.example/application/o/openbao/" &&
      vault_jwt_auth_backend_role.oidc.user_claim == "sub" &&
      vault_jwt_auth_backend_role.oidc.groups_claim == "groups" &&
      vault_jwt_auth_backend_role.oidc.bound_audiences == toset(["openbao"]) &&
      vault_jwt_auth_backend_role.oidc.allowed_redirect_uris == toset([
        "https://openbao.example/ui/vault/auth/oidc/oidc/callback",
        "http://localhost:8250/oidc/callback",
      ]) &&
      vault_jwt_auth_backend_role.oidc.token_ttl == 3600 &&
      vault_jwt_auth_backend_role.oidc.token_max_ttl == 3600 &&
      vault_jwt_auth_backend_role.oidc.token_policies == toset(["default"])
    )
    error_message = "OIDC must use the stable subject, exact UI/CLI callbacks, groups claim, and no team policies on the login role."
  }

  assert {
    condition = (
      vault_identity_group.team["pt-example/openbao-secret-readers"].type == "external" &&
      vault_identity_group_alias.team["pt-example/openbao-secret-readers"].name == "pt-example: OpenBao Secret Readers" &&
      vault_identity_group.team["pt-example/openbao-secret-readers"].policies == toset(["pt-example-openbao-secret-readers"])
    )
    error_message = "Only an exact matching Authentik group alias may attach a team policy to the user's OpenBao identity."
  }
}

run "team_kv2_mount_is_version_two" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      vault_mount.team_kv2.path == "kv2" &&
      vault_mount.team_kv2.type == "kv" &&
      vault_mount.team_kv2.options["version"] == "2"
    )
    error_message = "Team secrets must use the dedicated KV v2 mount."
  }
}

run "github_actions_sandbox_roles_keep_pr_and_approval_bindings" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      vault_jwt_auth_backend.github_actions.path == "github-actions" &&
      vault_jwt_auth_backend.github_actions.bound_issuer == "https://token.actions.githubusercontent.com" &&
      vault_jwt_auth_backend_role.github_actions["plan"].bound_subject == "repo:osinfra-io/pt-pneuma:pull_request" &&
      vault_jwt_auth_backend_role.github_actions["apply"].bound_subject == "repo:osinfra-io/pt-pneuma:environment:Sandbox OpenBao%3A us-east1-b" &&
      alltrue([
        for access, role in vault_jwt_auth_backend_role.github_actions :
        role.bound_claims["ref"] == "refs/pull/*/merge" &&
        role.bound_claims["event_name"] == "pull_request" &&
        role.bound_claims["repository_id"] == "1093115151" &&
        role.bound_claims["repository_owner_id"] == "104685378" &&
        role.bound_claims_type == "glob" &&
        role.bound_audiences == toset(["pt-pneuma-openbao"]) &&
        role.token_policies == toset(["pt-pneuma-openbao-${access}"]) &&
        role.token_ttl == 900 &&
        role.token_max_ttl == 900 &&
        role.token_explicit_max_ttl == 900
      ])
    )
    error_message = "GitHub roles must preserve PR claims, immutable repository bindings, protected apply subject, and short-lived access."
  }

  assert {
    condition = (
      strcontains(vault_policy.github_actions["plan"].policy, "path \"auth/github-actions/config\"") &&
      !strcontains(vault_policy.github_actions["plan"].policy, "\"update\"") &&
      !strcontains(vault_policy.github_actions["plan"].policy, "\"sudo\"") &&
      strcontains(vault_policy.github_actions["apply"].policy, "path \"auth/github-actions/role/pt-pneuma-openbao-*\"")
    )
    error_message = "Plan must read the imported authentication configuration without write access; apply must manage its GitHub roles."
  }

  assert {
    condition = alltrue(flatten([
      for policy in vault_policy.github_actions : [
        for backend in ["github-actions", "oidc"] :
        strcontains(policy.policy, "path \"sys/mounts/auth/${backend}\" {\n  capabilities = [\"read\"]\n}")
      ]
    ]))
    error_message = "Both workflow policies must allow the provider to inspect each managed authentication mount during import and refresh."
  }
}

run "github_actions_plan_reads_team_acl_policies_read_only" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      alltrue([
        for team_key_prefix in ["ct-", "et-", "pt-", "st-"] :
        strcontains(vault_policy.github_actions["plan"].policy, "path \"sys/policies/acl/${team_key_prefix}*\" {\n  capabilities = [\"read\"]\n}")
      ]) &&
      !strcontains(vault_policy.github_actions["plan"].policy, "\"create\"") &&
      !strcontains(vault_policy.github_actions["plan"].policy, "\"delete\"") &&
      !strcontains(vault_policy.github_actions["plan"].policy, "\"update\"")
    )
    error_message = "Plan must only read ACL policies for valid team-key prefixes."
  }
}

run "github_actions_apply_manages_only_declared_team_acl_policies" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      alltrue([
        for path in concat(
          [
            "sys/policies/acl/pt-pneuma-openbao-apply",
            "sys/policies/acl/pt-pneuma-openbao-plan",
          ],
          [
            for key in keys(local.openbao_groups) :
            "sys/policies/acl/${replace(key, "/", "-")}"
          ],
        ) :
        strcontains(vault_policy.github_actions["apply"].policy, "path \"${path}\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}") ||
        strcontains(vault_policy.github_actions["apply"].policy, "path \"${path}\" {\n  capabilities = [\"create\",\"read\",\"update\",\"delete\"]\n}")
      ]) &&
      alltrue([
        for key in keys(local.openbao_groups) :
        strcontains(vault_policy.github_actions["apply"].policy, "path \"sys/policies/acl/${replace(key, "/", "-")}\" {")
      ]) &&
      !strcontains(vault_policy.github_actions["apply"].policy, "sys/policies/acl/pt-pneuma-openbao-*") &&
      toset([
        for path_line in split("\n", vault_policy.github_actions["apply"].policy) :
        trimsuffix(trimprefix(trimspace(path_line), "path \""), "\" {")
        if strcontains(trimspace(path_line), "path \"sys/policies/acl/") &&
        strcontains(trimspace(path_line), "-openbao-secret-")
        ]) == toset([
        for key in keys(local.openbao_groups) :
        "sys/policies/acl/${replace(key, "/", "-")}"
      ])
    )
    error_message = "Apply must manage only exact declared team ACL policy names and baseline workflow ACL policies."
  }
}

run "team_policy_removal_keeps_apply_authorization" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "sb"
      environment = "sandbox"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
      teams       = {}
    }
  }

  assert {
    condition = (
      length(vault_policy.team) == 0 &&
      length(vault_identity_group.team) == 0 &&
      length(vault_identity_group_alias.team) == 0 &&
      strcontains(vault_policy.github_actions["apply"].policy, "path \"sys/policies/acl/pt-pneuma-openbao-apply\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}") &&
      strcontains(vault_policy.github_actions["apply"].policy, "path \"sys/policies/acl/pt-pneuma-openbao-plan\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}") &&
      !strcontains(vault_policy.github_actions["apply"].policy, "-openbao-secret-")
    )
    error_message = "Apply authorization must remain during team policy cleanup while removed team ACL paths are pruned."
  }
}

run "declared_group_changes_limit_apply_authorization_to_current_policies" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "sb"
      environment = "sandbox"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
      teams = {
        pt-example = {
          authentik_groups = {
            openbao-secret-writers = {
              label = "OpenBao Secret Writers"
              name  = "pt-example: OpenBao Secret Writers"
            }
          }
        }
        st-security = {
          authentik_groups = {
            openbao-secret-readers = {
              label = "OpenBao Secret Readers"
              name  = "st-security: OpenBao Secret Readers"
            }
          }
        }
      }
    }
  }

  assert {
    condition = (
      alltrue([
        for path in concat(
          [
            "sys/policies/acl/pt-pneuma-openbao-apply",
            "sys/policies/acl/pt-pneuma-openbao-plan",
          ],
          [
            for key in keys(local.openbao_groups) :
            "sys/policies/acl/${replace(key, "/", "-")}"
          ],
        ) :
        strcontains(vault_policy.github_actions["apply"].policy, "path \"${path}\" {\n  capabilities = [\"create\", \"read\", \"update\", \"delete\"]\n}") ||
        strcontains(vault_policy.github_actions["apply"].policy, "path \"${path}\" {\n  capabilities = [\"create\",\"read\",\"update\",\"delete\"]\n}")
      ]) &&
      alltrue([
        for key in keys(local.openbao_groups) :
        strcontains(vault_policy.github_actions["apply"].policy, "path \"sys/policies/acl/${replace(key, "/", "-")}\" {")
      ]) &&
      toset([
        for path_line in split("\n", vault_policy.github_actions["apply"].policy) :
        trimsuffix(trimprefix(trimspace(path_line), "path \""), "\" {")
        if strcontains(trimspace(path_line), "path \"sys/policies/acl/") &&
        strcontains(trimspace(path_line), "-openbao-secret-")
        ]) == toset([
        for key in keys(local.openbao_groups) :
        "sys/policies/acl/${replace(key, "/", "-")}"
      ])
    )
    error_message = "Apply ACL policy paths must track only currently declared OpenBao groups."
  }
}

run "github_actions_nonproduction_roles_use_main" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "nonprod"
      environment = "non-production"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
      teams       = {}
    }
  }

  assert {
    condition = (
      vault_jwt_auth_backend_role.github_actions["plan"].bound_subject == "repo:osinfra-io/pt-pneuma:ref:refs/heads/main" &&
      vault_jwt_auth_backend_role.github_actions["apply"].bound_subject == "repo:osinfra-io/pt-pneuma:environment:Non-Production OpenBao%3A us-east1-b" &&
      alltrue([
        for role in vault_jwt_auth_backend_role.github_actions :
        role.bound_claims["ref"] == "refs/heads/main" &&
        role.bound_claims["event_name"] == "push,workflow_dispatch"
      ])
    )
    error_message = "Non-production roles must accept only main-branch push/dispatch runs, with protected environment binding for apply."
  }
}
