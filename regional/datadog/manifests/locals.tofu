# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"

  # Clusters in this zone whose owning team has opted in to platform-managed Datadog.
  datadog_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if try(module.core_helpers.teams[cluster_config.team_key].enable_platform_managed_datadog, false)
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-pneuma-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # This deployment zone, parsed from the workspace name. Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
