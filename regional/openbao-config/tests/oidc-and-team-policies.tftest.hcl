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
      strcontains(local.team_policy_documents["pt-example/openbao-secret-readers"], "path \"team-kv/data/pt-example/*\"") &&
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
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "team-kv/delete/") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "team-kv/undelete/") &&
      !strcontains(local.team_policy_documents["pt-example/openbao-secret-writers"], "team-kv/destroy/")
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
      strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "team-kv/data/pt-example/*") &&
      strcontains(local.team_policy_documents["pt-example/openbao-secret-admins"], "team-kv/metadata/pt-example/*") &&
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
          "team-kv/data/${group.team_key}/*",
          "team-kv/metadata/${group.team_key}/*",
          "team-kv/metadata/${group.team_key}",
          "team-kv/delete/${group.team_key}/*",
          "team-kv/destroy/${group.team_key}/*",
          "team-kv/undelete/${group.team_key}/*",
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

run "team_kv_mount_is_version_two" {
  command = plan

  module {
    source = "./tests/fixtures"
  }

  assert {
    condition = (
      vault_mount.team_kv.path == "team-kv" &&
      vault_mount.team_kv.type == "kv" &&
      vault_mount.team_kv.options["version"] == "2"
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
      vault_jwt_auth_backend_role.github_actions["apply"].bound_subject == "repo:osinfra-io/pt-pneuma:environment:Sandbox OpenBao: us-east1-b" &&
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
      vault_jwt_auth_backend_role.github_actions["apply"].bound_subject == "repo:osinfra-io/pt-pneuma:environment:Non-Production OpenBao: us-east1-b" &&
      alltrue([
        for role in vault_jwt_auth_backend_role.github_actions :
        role.bound_claims["ref"] == "refs/heads/main" &&
        role.bound_claims["event_name"] == "push,workflow_dispatch"
      ])
    )
    error_message = "Non-production roles must accept only main-branch push/dispatch runs, with protected environment binding for apply."
  }
}
