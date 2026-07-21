# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  datadog_mci_synthetic_url          = module.core_helpers.environment == "production" ? "https://gcp.osinfra.io/${local.datadog_synthetic_service}/metadata/cluster-name" : "https://${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}/metadata/cluster-name"
  datadog_synthetic_message_critical = module.core_helpers.environment == "production" ? "@hangouts-Platform-CriticalHighPriority" : ""
  datadog_synthetic_message_medium   = module.core_helpers.environment == "production" ? "@hangouts-Platform-MediumLowInfoPriority" : ""
  datadog_synthetic_name             = "Istio Test"
  datadog_synthetic_service          = "istio-test"

  datadog_synthetic_tests = module.core_helpers.region == "us-east1" || module.core_helpers.zone == "b" ? {
    "mci" = {
      locations = [
        "aws:ca-central-1",
        "aws:us-west-1",
        "aws:us-east-1",
        "aws:eu-central-1",
        "aws:eu-south-1",
        "aws:eu-north-1",
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_critical
      message_priority = "1"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = "global"

      request_headers = {}

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "mci-us-east1" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "mci-us-east4" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "MCI ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = local.datadog_mci_synthetic_url
    }

    "us-east1" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "Ingress ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = module.core_helpers.environment == "production" ? "https://us-east1.gcp.osinfra.io/${local.datadog_synthetic_service}" : "https://us-east1.${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}"
    }

    "us-east4" = {
      locations = [
        "aws:us-east-1",
        "aws:us-east-2",
        "aws:us-west-1",
        "aws:us-west-2"
      ]

      message          = local.datadog_synthetic_message_medium
      message_priority = "3"
      name             = "Ingress ${local.datadog_synthetic_name}"
      region           = module.core_helpers.region

      request_headers = {
        Body = "services-${module.core_helpers.region}"
      }

      service = local.datadog_synthetic_service
      status  = "paused"
      url     = module.core_helpers.environment == "production" ? "https://us-east4.gcp.osinfra.io/${local.datadog_synthetic_service}" : "https://us-east4.${module.core_helpers.env}.gcp.osinfra.io/${local.datadog_synthetic_service}"
    }
  } : {}

  # Resolved DNS subdomain per team — the team's dns_subdomain from Logos, or the team key with
  # its topology prefix stripped (e.g. "pt-kryptos" → "kryptos"). Applied as the
  # osinfra.io/route-prefix namespace label so istio-test HTTPRoutes attach to the team's listener.
  dns_subdomains = {
    for team_key, team in module.core_helpers.teams :
    team_key => team.dns_subdomain != null ? team.dns_subdomain : replace(team_key, "/^[a-z]+-/", "")
  }

  # The pneuma gateway cluster in this zone (the platform team's own cluster). All external
  # ingress terminates here, so peer teams' istio-test backends must be resolvable locally.
  gateway_cluster = one([
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name
    if cluster_config.team_key == module.core_helpers.team
  ])

  # Selectorless stub Services (and their namespaces) created on the pneuma gateway cluster for
  # each peer team's istio-test. Gateway API HTTPRoute backendRefs require the backend Service
  # object to exist locally on the gateway cluster (otherwise ResolvedRefs reports
  # BackendNotFound); Istio multicluster endpoint discovery then fills their endpoints from the
  # remote team clusters. The map value is the team's route prefix, applied as the
  # osinfra.io/route-prefix label so the namespace attaches routes to that team's gateway listener.
  # Empty when there is no gateway cluster in this zone.
  gateway_stub_namespaces = local.gateway_cluster == null ? {} : {
    for cluster_name, cluster_config in local.gke_clusters :
    "${cluster_config.team_key}-istio-test" => local.dns_subdomains[cluster_config.team_key]
    if cluster_config.team_key != module.core_helpers.team
  }

  gateway_stub_services = local.gateway_cluster == null ? {} : merge([
    for cluster_name, cluster_config in local.gke_clusters : {
      "${cluster_config.team_key}-istio-test/istio-test" = {
        namespace = "${cluster_config.team_key}-istio-test"
        service   = "istio-test"
      }

      "${cluster_config.team_key}-istio-test/istio-test-${local.zone}" = {
        namespace = "${cluster_config.team_key}-istio-test"
        service   = "istio-test-${local.zone}"
      }
    }
    if cluster_config.team_key != module.core_helpers.team
  ]...)

  kubernetes_project = data.terraform_remote_state.main.outputs.project_id
  registry           = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"

  # GKE clusters in this zone — the subset that actually receives the istio-test harness.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Namespace per cluster. Pneuma (platform team) uses "istio-test"; member team clusters
  # use a team-prefixed namespace (e.g. "pt-kryptos-istio-test") so each team's workload
  # is isolated and Istio routing targets only that team's cluster pods.
  namespace = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key != module.core_helpers.team ? "${cluster_config.team_key}-istio-test" : "istio-test"
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-test-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
