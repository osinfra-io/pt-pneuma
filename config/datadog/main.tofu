# Datadog Monitor Resource
# https://search.opentofu.org/provider/datadog/datadog/latest/docs/resources/monitor

resource "datadog_monitor" "cloud_armor_anomalous_request_volume" {
  evaluation_delay = 900
  message          = <<-EOT
    {{#is_recovery}}
    ## Recovered

    Request volume is back within its expected range.
    {{/is_recovery}}

    {{^is_recovery}}
    ## What's happening?

    The number of requests that Google Cloud Armor security policy {{policy_name.name}} evaluates for backend {{backend_target_name.name}} in project {{project_id.name}} ({{location.name}}) has stayed above its expected range for 15 minutes. Share of points outside the expected range over the last 15 minutes: {{value}}.

    ---

    ## Impact

    Requests that the policy allows reach the backend. A large enough surge can flood the backend's instances and block access for legitimate users. The **Denied request rate is high** monitor does not alert on a surge that the policy allows.

    ---

    ## Why?

    Possible causes:

    * **Layer 7 DDoS attack**: An HTTP flood sends a spike of requests to the backend service.
    * **Legitimate traffic event**: A product launch or a batch job raises request volume above the expected range.
    * **Routing change**: Clients moved onto this backend raise its volume until the expected range adjusts to the new level.

    ---

    ## How to troubleshoot and resolve the issue?

    1. **Check the scope and outcome**: In the Google Cloud console, open the **Cloud Armor policies overview** dashboard in Monitoring. Check whether the rise is limited to this policy and backend, and whether allowed or denied requests account for it.
    2. **Find the sources**: On the **Cloud Armor policies** page, select **View logs** for this policy. Compare the client IP addresses, request paths, and user agents behind the new volume. Request logs require logging on the backend service, which is off by default for new backend services.
    3. **Check backend health**: On the **Load balancing** page, open the load balancer and read the **Healthy** column under **Backend**.
    4. **Resolve the cause**: For hostile sources, add a throttle or rate-based ban rule to the existing policy. Google recommends against creating a new security policy during an attack. With Google Cloud Armor Enterprise and Adaptive Protection enabled on the policy, Adaptive Protection alerts include a suggested rule for the attack signature. For legitimate traffic, scale the backend.

    ---

    ## Related links

    * [Datadog Google Cloud Armor integration docs](https://docs.datadoghq.com/integrations/google-cloud-armor/)
    * [Metrics Explorer](/metric/explorer?exp_metric=gcp.networksecurity.https.request_count&exp_scope=policy_name:{{policy_name.name}},backend_target_name:{{backend_target_name.name}},project_id:{{project_id.name}},location:{{location.name}}&exp_agg=sum&exp_type=bars)
    * [Google Cloud Armor Security Command Center findings](https://docs.cloud.google.com/armor/docs/cscc-findings)
    * [Google Cloud Armor rate limiting overview](https://docs.cloud.google.com/armor/docs/rate-limiting-overview)
    * [Google Cloud Armor Adaptive Protection overview](https://docs.cloud.google.com/armor/docs/adaptive-protection-overview)
    {{/is_recovery}}

    ${local.datadog_monitor_team_notification}
    EOT
  monitor_thresholds {
    critical          = 1
    critical_recovery = 0
  }
  monitor_threshold_windows {
    recovery_window = "last_15m"
    trigger_window  = "last_15m"
  }
  name                = "[Google Cloud Armor] Request volume is higher than usual"
  new_group_delay     = 60
  on_missing_data     = "default"
  query               = "avg(last_15m):anomalies(sum:gcp.networksecurity.https.request_count{*} by {project_id,location,policy_name,backend_target_name}.as_count(), 'agile', 2, direction='above', interval=60, alert_window='last_15m', count_default_zero='true', seasonality='weekly') >= 1"
  require_full_window = false
  tags = [
    "env:${module.core_helpers.environment}",
    "google_cloud_armor_monitor:anomalous_request_volume",
    "integration:google-cloud-armor",
    "product:google-cloud-armor",
    "team:${module.core_helpers.team}"
  ]
  type = "query alert"
}

resource "datadog_monitor" "cloud_armor_denied_request_rate" {
  evaluation_delay = 900
  message          = <<-EOT
    {{#is_alert}}
    ## What's happening?

    Google Cloud Armor security policy {{policy_name.name}} denied at least {{value}}% of the requests to backend {{backend_target_name.name}} in project {{project_id.name}} ({{location.name}}) over the last 15 minutes, above the {{threshold}}% threshold. Below 100 requests in that period, the query divides by 100, so the true share is higher.
    {{/is_alert}}

    {{#is_warning}}
    ## What's happening?

    Google Cloud Armor security policy {{policy_name.name}} denied at least {{value}}% of the requests to backend {{backend_target_name.name}} in project {{project_id.name}} ({{location.name}}) over the last 15 minutes, above the {{warn_threshold}}% warning threshold. Below 100 requests in that period, the query divides by 100, so the true share is higher.
    {{/is_warning}}

    {{#is_recovery}}
    ## Recovered

    The denied request share is back under the threshold. Current value: {{value}}%.
    {{/is_recovery}}

    {{^is_recovery}}
    ---

    ## Impact

    A denied request gets an error response and never reaches the backend. A denied attack leaves the backend unaffected. A misconfigured rule blocks the legitimate clients it matches.

    ---

    ## Why?

    Google publishes no recommended threshold for the denied request share, so the 5% and 20% thresholds are Datadog defaults.

    Possible causes:

    * **Attack in progress**: A web application firewall (WAF), rate-limiting, or IP address rule denies hostile traffic.
    * **Rule moved out of preview**: A rule tested in preview mode denies real traffic after enforcement.
    * **Overbroad rule**: A preconfigured WAF rule or IP address denylist matches more traffic than intended.
    * **Rate limit set too low**: A throttle or rate-based ban rule denies normal traffic bursts.
    * **Allowlist drift**: Clients moved to an address range or region the policy does not allow.

    ---

    ## How to troubleshoot and resolve the issue?

    1. **Check the scope**: In the Google Cloud console, open the **Cloud Armor policies overview** dashboard in Monitoring, and check whether other policies or backends also rose.
    2. **Find the denying rule and clients**: On the **Cloud Armor policies** page, select **View logs** for this policy, and read `enforcedSecurityPolicy.priority`, `enforcedSecurityPolicy.preconfiguredExprIds`, and `securityPolicyRequestData.remoteIpInfo.ipAddress` on the denied entries. Denials from a few client IP addresses suggest an attack, and denials across many ordinary clients suggest a misconfigured rule. Logging must be enabled on the backend service.
    3. **Check recent policy changes**: In **Logs Explorer**, compare the times of `addRule`, `patchRule`, and `removeRule` Admin Activity audit logs for this policy with the rise.
    4. **Resolve the cause**: Return a misconfigured rule to preview mode, then narrow its match condition or raise its `rate_limit_threshold_count`. Add the new client ranges or regions to the allowlist. Keep rules that deny an attack enforced.

    ---

    ## Related links

    * [Datadog Google Cloud Armor integration docs](https://docs.datadoghq.com/integrations/google-cloud-armor/)
    * [Metrics Explorer](/metric/explorer?exp_metric=gcp.networksecurity.https.request_count&exp_scope=policy_name:{{policy_name.name}},backend_target_name:{{backend_target_name.name}},project_id:{{project_id.name}},location:{{location.name}}&exp_agg=sum&exp_type=bars)
    * [Google Cloud Armor per-request logging](https://docs.cloud.google.com/armor/docs/request-logging)
    * [Google Cloud Armor security policy overview](https://docs.cloud.google.com/armor/docs/security-policy-overview)
    * [Google Cloud Armor rate limiting overview](https://docs.cloud.google.com/armor/docs/rate-limiting-overview)
    {{/is_recovery}}

    ${local.datadog_monitor_team_notification}
    EOT
  monitor_thresholds {
    critical          = 20
    critical_recovery = 5
    warning           = 5
  }
  name                = "[Google Cloud Armor] Denied request rate is high"
  new_group_delay     = 60
  on_missing_data     = "default"
  query               = "sum(last_15m):(sum:gcp.networksecurity.https.request_count{blocked:true} by {project_id,location,policy_name,backend_target_name}.as_count() / clamp_min(sum:gcp.networksecurity.https.request_count{*} by {project_id,location,policy_name,backend_target_name}.as_count(), 100)) * 100 > 20"
  require_full_window = false
  tags = [
    "env:${module.core_helpers.environment}",
    "google_cloud_armor_monitor:high_denied_request_rate",
    "integration:google-cloud-armor",
    "product:google-cloud-armor",
    "team:${module.core_helpers.team}"
  ]
  type = "query alert"
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
