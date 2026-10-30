# Test
# https://opentofu.org/docs/cli/commands/test

run "host_scoped_managed_access" {
  command = plan

  variables {
    policies = {
      ui = {
        host            = "agentgateway.localhost"
        path            = "/ui"
        required_groups = ["pt-pneuma: agentgateway Admins"]
      }
      config = {
        host            = "agentgateway.localhost"
        path            = "/config_dump"
        required_groups = ["pt-pneuma: agentgateway Admins"]
      }
    }
  }

  assert {
    condition = alltrue([
      for manifest in values(output.custom_authorization_policy_manifests) :
      manifest.spec.action == "CUSTOM" && manifest.spec.provider.name == "authentik"
    ])
    error_message = "Managed browser access must delegate to Authentik, not a local authorization filter."
  }

  assert {
    condition     = !contains(output.resolved_policies.ui.exempt_paths, "/ui/health")
    error_message = "Managed admin paths must not acquire implicit public health exemptions."
  }
}

run "different_requirements_on_one_host_rejected" {
  command = plan

  variables {
    policies = {
      ui = {
        host            = "agentgateway.localhost"
        path            = "/ui"
        required_groups = ["pt-pneuma: agentgateway Admins"]
      }
      reports = {
        host            = "agentgateway.localhost"
        path            = "/reports"
        required_groups = ["st-example: Reports Readers"]
      }
    }
  }

  expect_failures = [var.policies]
}
