# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  datadog_synthetic_service = "istio-test"
  datadog_synthetic_status  = module.core_helpers.env == "prod" ? "live" : "paused"

  # Create all teams' synthetic tests from one stable workspace to prevent duplicate ownership.
  datadog_synthetic_tests = local.zone == "us-east1-b" ? merge(
    {
      for team_key, domain in local.team_dns_domains :
      "${team_key}-global-mci" => {
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "Istio Test: Global MCI"
        region           = "global"
        request_headers  = {}
        service          = local.datadog_synthetic_service
        status           = local.datadog_synthetic_status
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
        follow_redirects = false
        locations        = [local.datadog_synthetic_location_by_region[test.region]]
        message_priority = "3"
        name             = "Istio Test: Regional MCI"
        region           = test.region
        request_headers = {
          Body = "services-${test.region}"
        }

        service  = local.datadog_synthetic_service
        status   = local.datadog_synthetic_status
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
        follow_redirects = false
        locations        = [local.datadog_synthetic_location_by_region[test.region]]
        message_priority = "3"
        name             = "Istio Test: Regional Ingress"
        region           = test.region
        request_headers = {
          Body = "services-${test.region}"
        }

        service  = local.datadog_synthetic_service
        status   = local.datadog_synthetic_status
        team_key = test.team_key
        url      = "https://${test.zone}.${test.domain}/${local.datadog_synthetic_service}/metadata/cluster-name"
      }
    },
    {
      "${module.core_helpers.team}-authentik-global" = {
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "authentik: Global Health"
        region           = "global"
        request_headers  = {}
        service          = "authentik"
        status           = local.datadog_synthetic_status
        team_key         = module.core_helpers.team
        url              = "${local.main.authentik_base_url}/-/health/ready/"
      }

      "${module.core_helpers.team}-openbao-global" = {
        follow_redirects = false
        locations        = local.datadog_synthetic_global_locations
        message_priority = "1"
        name             = "OpenBao: Global Health"
        region           = "global"
        request_headers  = {}
        service          = "openbao"
        status           = local.datadog_synthetic_status
        team_key         = module.core_helpers.team
        url              = "https://${local.main.openbao_hostname}/v1/sys/health?standbyok=true"
      }
    }
  ) : {}

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

  # GKE clusters in this zone — the subset that actually receives the istio-test harness.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Namespace per cluster — team-prefixed for every team, including pneuma (e.g.
  # "pt-pneuma-istio-test"). Each team's istio-test workload is isolated in its own namespace, so
  # Istio routing targets only that team's cluster pods.
  namespace = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => "${cluster_config.team_key}-istio-test"
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-pneuma-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
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

  main = data.terraform_remote_state.main.outputs

  registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-test-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
