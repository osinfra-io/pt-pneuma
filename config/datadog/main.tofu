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
