# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
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

  registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-pneuma-virtual"

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-test-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
