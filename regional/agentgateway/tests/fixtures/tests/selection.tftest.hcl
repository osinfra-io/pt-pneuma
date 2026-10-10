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
    condition     = output.lookup_clusters == ["pt-pneuma-us-east1-b"] && output.cluster_endpoint == "https://192.0.2.1"
    error_message = "Only the selected Pneuma cluster may be looked up and used by the single provider."
  }

}

run "nonproduction_not_enabled" {
  command = plan

  variables {
    test_environment = "non-production"
  }

  assert {
    condition     = length(output.clusters) == 0 && length(output.lookup_clusters) == 0 && output.cluster_endpoint == null
    error_message = "Temporary sandbox testing must not enable non-production deployment."
  }
}

run "production_not_enabled" {
  command = plan

  variables {
    test_environment = "production"
  }

  assert {
    condition     = length(output.clusters) == 0 && length(output.lookup_clusters) == 0 && output.cluster_endpoint == null
    error_message = "Temporary sandbox testing must not enable production deployment."
  }
}
mock_provider "google" {
  mock_data "google_container_cluster" {
    defaults = {
      endpoint = "192.0.2.1"
      master_auth = [{
        client_certificate = ""
        client_certificate_config = [{
          issue_client_certificate = false
        }]
        client_key             = ""
        cluster_ca_certificate = "bW9jay1jYQ=="
      }]
    }
  }

}
