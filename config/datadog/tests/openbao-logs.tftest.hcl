mock_provider "datadog" {}
mock_provider "google" {}

override_data {
  target = data.datadog_logs_pipelines.this
  values = {
    logs_pipelines = [
      {
        description  = ""
        filter       = [{ query = "source:first" }]
        id           = "existing-first"
        is_enabled   = true
        is_read_only = true
        name         = "Existing first"
        tags         = []
        type         = "pipeline"
      },
      {
        description  = ""
        filter       = [{ query = "service:openbao" }]
        id           = "openbao-pipeline"
        is_enabled   = true
        is_read_only = false
        name         = "OpenBao log severity"
        tags         = []
        type         = "pipeline"
      },
      {
        description  = ""
        filter       = [{ query = "source:last" }]
        id           = "existing-last"
        is_enabled   = true
        is_read_only = true
        name         = "Existing last"
        tags         = []
        type         = "pipeline"
      },
    ]
  }
}

override_data {
  target = data.terraform_remote_state.main
  values = {
    outputs = {
      authentik_base_url = "https://authentik.example"
      openbao_hostname   = "openbao.example"
    }
  }
}

override_resource {
  target = datadog_logs_custom_pipeline.openbao
  values = {
    id = "openbao-pipeline"
  }
}

variables {
  datadog_api_key = "test"
  datadog_app_key = "test"
}

run "production_orders_severity_before_other_remappers" {
  command = plan

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "prod"
      environment = "production"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
    }
  }

  assert {
    condition     = datadog_logs_pipeline_order.this.pipelines == tolist(["openbao-pipeline", "existing-first", "existing-last"])
    error_message = "The OpenBao severity pipeline must run first, without duplicates or reordering unrelated pipelines."
  }

  assert {
    condition = (
      datadog_logs_custom_pipeline.openbao.filter[0].query == "team:pt-pneuma kube_namespace:openbao service:(openbao OR vault-k8s)" &&
      datadog_logs_custom_pipeline.openbao.processor[0].grok_parser[0].is_enabled &&
      datadog_logs_custom_pipeline.openbao.processor[1].status_remapper[0].is_enabled &&
      datadog_logs_custom_pipeline.openbao.processor[1].status_remapper[0].sources == tolist(["openbao.level"])
    )
    error_message = "Server and injector logs must have their level parsed before the enabled status remapper, scoped to Pneuma's OpenBao namespace."
  }

  assert {
    condition = [
      for sample in datadog_logs_custom_pipeline.openbao.processor[0].grok_parser[0].samples :
      regex(
        replace(
          replace(
            replace(
              trimprefix(datadog_logs_custom_pipeline.openbao.processor[0].grok_parser[0].grok[0].match_rules, "openbao "),
              "%%{notSpace}", "\\S+"
            ),
            "%%{word:openbao.level}", "(\\b\\w+\\b)"
          ),
          "%%{data}", "(?s:.*)"
        ),
        sample
      )[0]
    ] == ["INFO", "WARN", "ERROR"]
    error_message = "The Grok rule's regex primitives must extract INFO, WARN, and ERROR from UTC server and injector samples."
  }
}

run "nonproduction_does_not_manage_shared_log_configuration" {
  command = plan

  override_module {
    target = module.core_helpers
    outputs = {
      env         = "nonprod"
      environment = "non-production"
      repository  = "pt-pneuma"
      team        = "pt-pneuma"
    }
  }

  assert {
    condition     = datadog_logs_custom_pipeline.openbao == null && datadog_logs_pipeline_order.this == null
    error_message = "Non-production must not compete with production for organization-wide log configuration."
  }
}
