# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  datadog_monitor_cloud_armor_anomalous_request_volume_query = "avg(last_15m):anomalies(sum:gcp.networksecurity.https.request_count{project_id:${local.main.project_id}} by {project_id,location,policy_name,backend_target_name}.as_count(), 'agile', 2, direction='above', interval=60, alert_window='last_15m', count_default_zero='true', seasonality='weekly') >= 1"

  datadog_monitor_cloud_armor_denied_request_rate_query = "sum(last_15m):(sum:gcp.networksecurity.https.request_count{blocked:true,project_id:${local.main.project_id}} by {project_id,location,policy_name,backend_target_name}.as_count() / clamp_min(sum:gcp.networksecurity.https.request_count{project_id:${local.main.project_id}} by {project_id,location,policy_name,backend_target_name}.as_count(), 100)) * 100 > 20"

  datadog_monitor_team_notification = "@team-${module.core_helpers.team}"

  datadog_synthetic_agentgateway_url = "${replace(local.main.authentik_base_url, "authentik.", "agentgateway.")}/ui"

  datadog_synthetic_global_locations = [
    "gcp:us-east4",
    "gcp:us-west1",
    "gcp:us-west2",
    "gcp:us-south1"
  ]

  datadog_synthetic_location_by_region = {
    us-east1 = "gcp:us-east4"
    us-east4 = "gcp:us-east4"
  }

  datadog_synthetic_service = "istio-test"

  datadog_synthetic_suite_alerting_threshold = 1.0 / max(1, length(local.datadog_synthetic_team_global_tests))

  datadog_synthetic_team_global_tests = {
    for test_name, test in local.datadog_synthetic_tests :
    test_name => test
    if test.team_key == module.core_helpers.team && test.region == "global"
  }

  datadog_synthetic_tests = merge(
    {
      for team_key, domain in local.team_dns_domains :
      "${team_key}-global-mci" => {
        expected_status  = "200"
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "Istio Test: Global MCI"
        region           = "global"
        request_headers  = {}
        service          = local.datadog_synthetic_service
        status           = var.datadog_synthetic_status
        team_key         = team_key
        url              = "https://${domain}/${local.datadog_synthetic_service}/metadata/cluster-name"
      }
    },
    {
      for test in flatten([
        for team_key, domain in local.team_dns_domains : [
          for region in local.team_regions[team_key] : {
            domain   = domain
            region   = region
            team_key = team_key
          }
        ]
      ]) :
      "${test.team_key}-${test.region}-regional-mci" => {
        expected_status  = "200"
        follow_redirects = false
        locations        = [local.datadog_synthetic_location_by_region[test.region]]
        message_priority = "3"
        name             = "Istio Test: Regional MCI"
        region           = test.region
        request_headers = {
          Body = "services-${test.region}"
        }

        service  = local.datadog_synthetic_service
        status   = var.datadog_synthetic_status
        team_key = test.team_key
        url      = "https://${test.domain}/${local.datadog_synthetic_service}/metadata/cluster-name"
      }
    },
    {
      for test in flatten([
        for team_key, domain in local.team_dns_domains : flatten([
          for region in local.team_regions[team_key] : [
            for zone in local.team_zones_by_region[team_key][region] : {
              domain   = domain
              region   = region
              team_key = team_key
              zone     = zone
            }
          ]
        ])
      ]) :
      "${test.team_key}-${test.zone}-regional-ingress" => {
        expected_status  = "200"
        follow_redirects = false
        locations        = [local.datadog_synthetic_location_by_region[test.region]]
        message_priority = "3"
        name             = "Istio Test: Regional Ingress"
        region           = test.region
        request_headers = {
          Body = "services-${test.region}"
        }

        service  = local.datadog_synthetic_service
        status   = var.datadog_synthetic_status
        team_key = test.team_key
        url      = "https://${test.zone}.${test.domain}/${local.datadog_synthetic_service}/metadata/cluster-name"
      }
    },
    {
      "${module.core_helpers.team}-agentgateway-global" = {
        expected_status  = "302"
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "agentgateway: Global Health"
        region           = "global"
        request_headers  = {}
        service          = "agentgateway"
        status           = var.datadog_synthetic_status
        team_key         = module.core_helpers.team
        url              = local.datadog_synthetic_agentgateway_url
      }

      "${module.core_helpers.team}-authentik-global" = {
        expected_status  = "200"
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "authentik: Global Health"
        region           = "global"
        request_headers  = {}
        service          = "authentik"
        status           = var.datadog_synthetic_status
        team_key         = module.core_helpers.team
        url              = "${local.main.authentik_base_url}/-/health/ready/"
      }

      "${module.core_helpers.team}-openbao-global" = {
        expected_status  = "200"
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "OpenBao: Global Health"
        region           = "global"
        request_headers  = {}
        service          = "openbao"
        status           = var.datadog_synthetic_status
        team_key         = module.core_helpers.team
        url              = "https://${local.main.openbao_hostname}/v1/sys/health?standbyok=true"
      }
    }
  )

  main = data.terraform_remote_state.main.outputs

  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # Team public DNS domains come from the main workspace's authoritative DNS configuration.
  team_dns_domains = {
    for team_key in keys(local.team_regions) :
    team_key => one(keys(try(local.main.gateway_dns[team_key], {})))
  }

  team_regions = {
    for team_key in toset([for cluster_config in values(var.clusters) : cluster_config.team_key]) :
    team_key => sort(tolist(toset([
      for cluster_name, cluster_config in var.clusters :
      local.regions[cluster_name]
      if cluster_config.team_key == team_key
    ])))
  }

  # Ingress routes exist only for teams with a cluster in that zone.
  team_zones_by_region = {
    for team_key in keys(local.team_regions) :
    team_key => {
      for region in local.team_regions[team_key] :
      region => sort(tolist(toset([
        for cluster_name, cluster_config in var.clusters :
        regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]
        if cluster_config.team_key == team_key && local.regions[cluster_name] == region
      ])))
    }
  }

}
