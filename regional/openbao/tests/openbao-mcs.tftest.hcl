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

run "datadog_vault_metrics_integration" {
  command = plan

  assert {
    condition = strcontains(
      yamldecode(local.openbao_dynamic_helm_values).server.ha.raft.config,
      "unauthenticated_metrics_access = true"
      ) && strcontains(
      yamldecode(local.openbao_dynamic_helm_values).server.ha.raft.config,
      "prometheus_retention_time = \"24h\""
    )
    error_message = "OpenBao must expose Prometheus metrics for the Datadog Vault integration."
  }

  assert {
    condition = jsondecode(
      yamldecode(file("${path.module}/helm/openbao.yml")).server.annotations["ad.datadoghq.com/openbao.checks"]
      ).vault.instances[0] == {
      api_url         = "https://%%host%%:8200/v1"
      detect_leader   = true
      no_token        = true
      tls_verify      = false
      use_openmetrics = true
    }
    error_message = "OpenBao pods must use unauthenticated, TLS-aware Datadog Vault OpenMetrics checks."
  }

  assert {
    condition = jsondecode(
      yamldecode(file("${path.module}/helm/openbao.yml")).server.annotations["ad.datadoghq.com/openbao.logs"]
      ) == [{
        service = "openbao"
        source  = "vault"
    }]
    error_message = "OpenBao server logs must use the Vault log source while retaining the OpenBao service."
  }

  assert {
    condition = jsondecode(
      yamldecode(file("${path.module}/helm/openbao.yml")).injector.annotations["ad.datadoghq.com/sidecar-injector.logs"]
      ) == [{
        service = "openbao-injector"
        source  = "vault"
    }]
    error_message = "OpenBao injector logs must use the Vault log source and the OpenBao injector service."
  }

  assert {
    condition     = yamldecode(file("${path.module}/helm/openbao.yml")).server.configAnnotation && yamldecode(file("${path.module}/helm/openbao.yml")).server.updateStrategyType == "RollingUpdate"
    error_message = "OpenBao must roll pods when its telemetry configuration changes."
  }
}
