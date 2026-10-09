mock_provider "authentik" {
  mock_resource "authentik_provider_oauth2" {
    defaults = {
      id = "1"
    }
  }

  mock_resource "authentik_provider_proxy" {
    defaults = {
      id = "2"
    }
  }
}

override_data {
  target = data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_base_url             = "https://authentik.sb.osinfra.io"
      authentik_kubernetes_namespace = "authentik"
      authentik_secret_env = {
        AUTHENTIK_BOOTSTRAP_TOKEN = "mock-token"
      }
      gateway_dns = {}
    }
  }
}

variables {
  sandbox_authentication_enabled = true
  state_bucket                   = "mock-state"
  state_kms_encryption_key       = "mock-kms"
  state_prefix                   = "mock-prefix"
}

run "cloud_sandbox_root" {
  command = apply

  assert {
    condition     = module.authentication.brands["sandbox"].domain == "authentik.sb.osinfra.io" && module.authentication.brands["sandbox"].branding_title == "osinfra.io | Sandbox" && module.authentication.flows["sandbox"].slug == "sandbox-authentication-flow" && module.authentication.flows["sandbox"].title == "Welcome to osinfra.io sandbox!"
    error_message = "The cloud root must pass the original sandbox identities and titles."
  }

  assert {
    condition = alltrue([
      for key, binding in module.authentication.stage_bindings :
      binding.stage == data.authentik_stage.sandbox_authentication_stages[key].id
      ]) && alltrue([
      for key, binding in module.authentication.policy_bindings :
      binding.policy == data.authentik_policy_expression.sandbox_authentication_stage_policies[key].id
    ])
    error_message = "The cloud root must pass its discovered stage and expression-policy IDs."
  }

  assert {
    condition     = output.cloud_inputs.external_host == "https://pneuma.sb.osinfra.io" && output.cloud_inputs.namespace == "authentik" && output.cloud_inputs.manage_default_authentication_stage && output.cloud_inputs.default_authentication_source_uuids == []
    error_message = "Extraction must not change cloud host/namespace discovery or default-stage management."
  }

  assert {
    condition     = output.cloud_inputs.redirect_uris[0].matching_mode == "regex" && output.cloud_inputs.redirect_uris[0].url == "https://([a-z0-9-]+\\.)*pneuma\\.sb\\.osinfra\\.io/outpost\\.goauthentik\\.io/callback.*"
    error_message = "Extraction must preserve the cloud callback restriction."
  }
}

run "cloud_nonproduction_custom_authentication_disabled" {
  command = apply

  variables {
    sandbox_authentication_enabled = false
    test_env                       = "nonprod"
  }

  assert {
    condition     = length(module.authentication.brands) == 0 && length(module.authentication.flows) == 0 && length(module.authentication.stage_bindings) == 0 && length(module.authentication.policy_bindings) == 0 && length(data.authentik_stage.sandbox_authentication_stages) == 0 && length(data.authentik_policy_expression.sandbox_authentication_stage_policies) == 0
    error_message = "Disabled cloud environments must not discover or create custom sandbox authentication objects."
  }

  assert {
    condition     = output.cloud_inputs.manage_default_authentication_stage && module.authentication.default_authentication_stage_settings.password_stage == null && module.authentication.default_authentication_stage_settings.case_insensitive_matching
    error_message = "The existing shared identification stage must remain managed when the custom flow is disabled."
  }

  assert {
    condition     = output.cloud_inputs.external_host == "https://pneuma.nonprod.osinfra.io"
    error_message = "Non-production host discovery must remain unchanged."
  }
}

run "cloud_production_custom_authentication_disabled" {
  command = apply

  variables {
    sandbox_authentication_enabled = false
    test_env                       = "prod"
  }

  assert {
    condition     = length(module.authentication.brands) == 0 && length(module.authentication.flows) == 0 && length(module.authentication.stage_bindings) == 0 && length(module.authentication.policy_bindings) == 0 && length(data.authentik_stage.sandbox_authentication_stages) == 0 && length(data.authentik_policy_expression.sandbox_authentication_stage_policies) == 0
    error_message = "Production must not discover or create custom sandbox authentication objects."
  }

  assert {
    condition     = output.cloud_inputs.external_host == "https://pneuma.osinfra.io" && output.cloud_inputs.manage_default_authentication_stage && module.authentication.default_authentication_stage_settings.password_stage == null
    error_message = "Production host discovery and identification-stage management must remain unchanged."
  }
}

run "cloud_managed_application_groups" {
  command = apply

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "sb"
      environment = "sandbox"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
      teams = {
        pt-pneuma = {
          dns_subdomain = "pneuma"
          authentik_groups = {
            agentgateway-admins = {
              description = "UI access"
              name        = "pt-pneuma: agentgateway Admins"
              members = {
                sandbox    = ["sandbox@example.com"]
                production = ["production@example.com"]
              }
            }
          }
        }
      }
    }
  }

  assert {
    condition     = module.team_access.application_groups["pt-pneuma/agentgateway-admins"].members == tolist(["sandbox@example.com"])
    error_message = "The cloud Authentik consumer must select only the current environment's declared members."
  }

  assert {
    condition     = module.authentik_config.application_groups["pt-pneuma/agentgateway-admins"].name == "pt-pneuma: agentgateway Admins" && !module.authentik_config.application_groups["pt-pneuma/agentgateway-admins"].is_superuser
    error_message = "The pinned module must create the owning team's named application group without Authentik superuser privileges."
  }
}
