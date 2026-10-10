# Test
# https://opentofu.org/docs/cli/commands/test

run "managed_paths_require_post_auth_authorization" {
  command = plan

  variables {
    application_group_members = {
      "pt-pneuma: agentgateway Admins" = ["member@example.com"]
    }
    policies = {
      ui = {
        host            = "agentgateway.localhost"
        path            = "/ui"
        required_groups = ["pt-pneuma: agentgateway Admins"]
      }
    }
  }

  assert {
    condition     = output.browser_authorization_filter_manifests.application_access.spec.priority == 10 && output.browser_authorization_filter_manifests.application_access.spec.configPatches[0].patch.operation == "INSERT_AFTER"
    error_message = "Managed authorization must follow ext_authz, never precede authentication."
  }

  assert {
    condition     = !contains(output.resolved_policies.ui.exempt_paths, "/ui/health")
    error_message = "An application's admin endpoints must not acquire implicit public health exemptions."
  }
}

run "unresolved_application_requirement_fails_closed" {
  command = plan

  variables {
    policies = {
      ui = {
        host            = "agentgateway.localhost"
        path            = "/ui"
        required_groups = ["pt-pneuma: agentgateway Admins"]
      }
    }
  }

  expect_failures = [var.policies]
}
