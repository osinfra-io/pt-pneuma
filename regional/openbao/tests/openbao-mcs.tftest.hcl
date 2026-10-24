mock_provider "google" {}

override_data {
  target = data.terraform_remote_state.main
  values = {
    outputs = {
      openbao_hostname = "openbao.example"
      openbao_kms_seal = {
        crypto_key = "openbao"
        key_ring   = "openbao"
        project    = "pt-example"
        region     = "us-east1"
      }
      openbao_kms_service_account_email = "openbao@example.iam.gserviceaccount.com"
      gke_clusters = {
        pt-pneuma-us-east1-b = {
          team_key = "pt-pneuma"
        }
        pt-pneuma-us-east4-a = {
          team_key = "pt-pneuma"
        }
        pt-other-us-east1-c = {
          team_key = "pt-other"
        }
      }
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
  }
}

variables {
  clusters = {}
}

run "global_openbao_endpoint_uses_only_supported_cluster" {
  command = plan

  assert {
    condition = local.openbao_multi_cluster_service_clusters == [
      {
        link = "us-east1/pt-pneuma-us-east1-b"
      },
    ]
    error_message = "The global OpenBao hostname must route only to the us-east1-b cluster while preserving team filtering."
  }
}
