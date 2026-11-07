# Datadog Logs Custom Pipeline Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/resources/logs_custom_pipeline

resource "datadog_logs_custom_pipeline" "openbao" {
  lifecycle {
    enabled = local.datadog_log_configuration_enabled
  }

  description = "Use the OpenBao server and injector log level instead of the container stderr stream."

  filter {
    query = local.openbao_log_filter
  }

  is_enabled = true
  name       = "OpenBao log severity"

  processor {
    grok_parser {
      grok {
        match_rules   = "openbao %%{notSpace}\\s+\\[%%{word:openbao.level}\\]\\s+%%{data}"
        support_rules = ""
      }

      is_enabled = true
      name       = "Extract the OpenBao log level"

      samples = [
        "2026-11-07T18:38:45.141Z [INFO]  storage.raft: starting autopilot",
        "2026-11-07T18:39:57.540Z [WARN]  handler: request warning",
        "2026-11-07T18:39:57.540Z [ERROR] handler: request failed",
      ]

      source = "message"
    }
  }

  processor {
    status_remapper {
      is_enabled = true
      name       = "Use the OpenBao log level as the status"
      sources    = ["openbao.level"]
    }
  }
}

# Datadog Logs Pipeline Order Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/resources/logs_pipeline_order

resource "datadog_logs_pipeline_order" "this" {
  lifecycle {
    enabled = local.datadog_log_configuration_enabled
  }

  name      = "pneuma"
  pipelines = local.datadog_log_pipeline_order
}

# Datadog Synthetics Suite Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/resources/synthetics_suite

resource "datadog_synthetics_suite" "pneuma" {
  message = "One or more critical Pneuma synthetic tests are failing."
  name    = "Pneuma Synthetics"

  options {
    alerting_threshold = local.datadog_synthetic_suite_alerting_threshold
  }

  tags = [
    "env:${module.core_helpers.environment}",
    "team:${module.core_helpers.team}"
  ]

  dynamic "tests" {
    for_each = local.datadog_synthetic_team_tests

    content {
      alerting_criticality = "critical"
      public_id            = datadog_synthetics_test.this[tests.key].id
    }
  }
}

# Datadog Synthetics Test Resource
# https://search.opentofu.org/provider/opentofu/datadog/latest/resources/synthetics_test

resource "datadog_synthetics_test" "this" {
  for_each = local.datadog_synthetic_tests

  assertion {
    operator = "is"
    target   = "200"
    type     = "statusCode"
  }

  assertion {
    operator = "lessThan"
    target   = 5000
    type     = "responseTime"
  }

  locations = each.value.locations
  name      = each.value.name

  options_list {
    follow_redirects = each.value.follow_redirects
    monitor_priority = each.value.message_priority

    retry {
      count    = 2
      interval = 120
    }

    tick_every = 3600
  }

  request_definition {
    method = "GET"
    url    = each.value.url
  }

  request_headers = each.value.request_headers

  status  = each.value.status
  subtype = "http"

  tags = [
    "env:${module.core_helpers.environment}",
    "region:${each.value.region}",
    "service:${each.value.service}",
    "team:${each.value.team_key}"
  ]

  type = "api"
}
