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
