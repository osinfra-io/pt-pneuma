# Test
# https://opentofu.org/docs/cli/commands/test

override_data {
  target = module.legacy_manifests.data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_kubernetes_namespace = "authentik"
      gateway_dns = {
        pt-pneuma = {
          "pneuma.sb.osinfra.io" = {}
        }
      }
    }
  }
}

override_data {
  target = module.legacy_manifests.data.terraform_remote_state.authentik_config
  values = {
    outputs = {}
  }
}

override_data {
  target = module.legacy_mesh.data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_kubernetes_namespace = "authentik"
      gateway_dns = {
        pt-pneuma = {
          "pneuma.sb.osinfra.io" = {}
        }
      }
      gke_clusters = {
        pt-pneuma-us-east1-b = {
          team_key = "pt-pneuma"
        }
      }
    }
  }
}

override_data {
  target = module.legacy_mesh.data.terraform_remote_state.authentik_config
  values = {
    outputs = {}
  }
}

run "production_parity" {
  command = plan

  assert {
    condition     = length(module.legacy_manifests.custom_manifests) == 2 && jsonencode(module.shared.custom_authorization_policy_manifests) == jsonencode(module.legacy_manifests.custom_manifests)
    error_message = "Shared CUSTOM rendering must equal the real production global/zonal browser manifests."
  }

  assert {
    condition     = jsonencode(module.shared.extension_provider) == jsonencode(module.legacy_mesh.extension_providers["pt-pneuma-us-east1-b"][0])
    error_message = "Shared mesh extension provider must equal production's fail-closed configuration."
  }

  assert {
    condition     = jsonencode(module.shared.callback_routes) == jsonencode(module.legacy_manifests.callback_routes["pt-pneuma-us-east1-b"])
    error_message = "Shared callback route names and backends must equal production."
  }

  assert {
    condition = alltrue([
      for key, policy in module.legacy_manifests.gateway_auth_authorization_policies :
      jsonencode(policy.paths) == jsonencode(module.shared.resolved_policies[key].paths) &&
      jsonencode(policy.exempt_paths) == jsonencode(module.shared.resolved_policies[key].exempt_paths) &&
      policy.deny_authorization_policy_name == module.shared.resolved_policies[key].deny_authorization_policy_name &&
      jsonencode(policy.required_groups) == jsonencode(module.shared.resolved_policies[key].required_groups)
    ])
    error_message = "Resolved policy paths, exemptions, names and group intent must not change."
  }

  assert {
    condition = length(module.legacy_manifests.jwt_manifests) == 2 && alltrue([
      for manifest in values(module.legacy_manifests.jwt_manifests) :
      manifest.spec.action == "DENY" &&
      length(manifest.spec.rules) == 4 &&
      manifest.spec.rules[0].from[0].source.notRequestPrincipals[0] == "*" &&
      manifest.spec.rules[1].when[0].key == "request.auth.audiences" &&
      jsonencode(manifest.spec.rules[1].when[0]) == jsonencode({ key = "request.auth.audiences", notValues = ["test-api"] }) &&
      manifest.spec.rules[2].when[0].key == "request.auth.claims[groups]" &&
      jsonencode(manifest.spec.rules[2].when[0]) == jsonencode({ key = "request.auth.claims[groups]", notValues = ["api-users"] }) &&
      manifest.spec.rules[3].when[0].key == "request.auth.claims[roles]" &&
      jsonencode(manifest.spec.rules[3].when[0]) == jsonencode({ key = "request.auth.claims[roles]", notValues = ["reader"] })
    ])
    error_message = "Production API JWT resources must retain principal/audience/group/role enforcement."
  }
}
