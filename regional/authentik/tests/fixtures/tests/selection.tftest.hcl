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

override_data {
  target = data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_kubernetes_namespace = "pt-pneuma-authentik"
    }
  }
}

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
}

run "sandbox_owning_team_and_zone_only" {
  command = plan

  assert {
    condition     = output.lookup_clusters == ["pt-pneuma-us-east1-b"] && output.cluster_endpoint == "https://192.0.2.1"
    error_message = "Authentik must contact only the owning team's cluster in the workspace's zone."
  }
}

run "nonproduction_still_enabled" {
  command = plan

  variables {
    test_environment = "non-production"
  }

  assert {
    condition     = output.lookup_clusters == ["pt-pneuma-us-east1-b"]
    error_message = "The targeted lookup must preserve non-production Authentik deployment."
  }
}

run "production_still_enabled" {
  command = plan

  variables {
    test_environment = "production"
  }

  assert {
    condition     = output.lookup_clusters == ["pt-pneuma-us-east1-b"]
    error_message = "The targeted lookup must preserve production Authentik deployment."
  }
}

run "unrelated_cluster_only" {
  command = plan

  variables {
    clusters = {
      st-example-us-east1-b = {
        project_id = "mock-example"
        team_key   = "st-example"
      }
    }
  }

  assert {
    condition     = length(output.lookup_clusters) == 0 && output.cluster_endpoint == null
    error_message = "An unrelated cluster must not initialize Authentik's connection."
  }
}
