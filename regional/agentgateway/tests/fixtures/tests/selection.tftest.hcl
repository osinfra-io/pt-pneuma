variables {
  clusters = {
    pt-pneuma-us-east1-b = {
      project_id = "mock-pneuma"
      team_key   = "pt-pneuma"
    }
    pt-pneuma-us-east4-a = {
      project_id = "mock-pneuma"
      team_key   = "pt-pneuma"
    }
    st-example-us-east1-b = {
      project_id = "mock-example"
      team_key   = "st-example"
    }
  }
  state_bucket             = "mock-state"
  state_kms_encryption_key = "mock-key"
  state_prefix             = "mock-prefix"
}

run "owning_team_and_zone_only" {
  command = plan

  assert {
    condition     = keys(output.clusters) == ["pt-pneuma-us-east1-b"] && output.namespace == "pt-pneuma-agentgateway"
    error_message = "Sandbox agentgateway must deploy only to the owning team's cluster in this workspace's zone."
  }

  assert {
    condition     = output.admin_allow.spec.action == "ALLOW" && output.admin_allow.spec.rules[0].from[0].source.principals == ["cluster.local/ns/istio-ingress/sa/gateway-istio"] && output.admin_allow.spec.rules[0].to[0].operation.ports == ["15000"]
    error_message = "Only the authenticated ingress gateway may reach the admin port through mesh default-deny."
  }

  assert {
    condition     = output.admin_deny.spec.action == "DENY" && output.admin_deny.spec.rules[0].from[0].source.notPrincipals == ["cluster.local/ns/istio-ingress/sa/gateway-istio"] && output.admin_deny.spec.rules[0].to[0].operation.ports == ["15000"]
    error_message = "Other in-mesh workloads must not bypass browser authentication by reaching the admin port directly."
  }
}

run "nonproduction_not_enabled" {
  command = plan

  variables {
    test_environment = "non-production"
  }

  assert {
    condition     = length(output.clusters) == 0
    error_message = "Temporary sandbox testing must not enable non-production deployment."
  }
}

run "production_not_enabled" {
  command = plan

  variables {
    test_environment = "production"
  }

  assert {
    condition     = length(output.clusters) == 0
    error_message = "Temporary sandbox testing must not enable production deployment."
  }
}
