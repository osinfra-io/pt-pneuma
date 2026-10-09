# Test
# https://opentofu.org/docs/cli/commands/test

run "explicit_sandbox_members" {
  command = plan

  variables {
    environment = "sandbox"
    teams = {
      pt-pneuma = {
        authentik_groups = {
          agentgateway-admins = {
            description = "UI access"
            label       = "agentgateway Admins"
            members = {
              production = ["production@example.com"]
              sandbox    = ["sandbox@example.com"]
            }
          }
        }
      }
      st-example = {
        authentik_groups = {
          readers = {
            description = "Reports access"
            name        = "st-example: Reports Readers"
          }
        }
      }
    }
  }

  assert {
    condition     = output.application_group_members["pt-pneuma: agentgateway Admins"] == tolist(["sandbox@example.com"])
    error_message = "Sandbox access must never inherit production members."
  }

  assert {
    condition     = length(output.application_group_members["st-example: Reports Readers"]) == 0
    error_message = "Omitted environment lists must deny access rather than inherit team membership."
  }

  assert {
    condition     = output.application_groups["pt-pneuma/agentgateway-admins"].name == "pt-pneuma: agentgateway Admins"
    error_message = "Stable identifiers must preserve team ownership and product branding."
  }
}

run "legacy_team_without_groups" {
  command = plan

  variables {
    environment = "production"
    teams       = { pt-legacy = {} }
  }

  assert {
    condition     = length(output.application_groups) == 0
    error_message = "Existing team declarations must not acquire implicit application access."
  }
}

run "invalid_environment" {
  command = plan

  variables {
    environment = "prod"
    teams       = {}
  }

  expect_failures = [var.environment]
}
