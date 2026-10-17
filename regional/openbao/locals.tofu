# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters in this zone owned by pt-pneuma — the subset that actually receives OpenBao.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}") && cluster_config.team_key == module.core_helpers.team
  }

  # Helm set values derived from OpenTofu context and environment-specific variables.
  helm_set_values = concat(
    [
      {
        name  = "server.extraLabels.env"
        value = module.core_helpers.environment
      },
      {
        name  = "server.extraLabels.team"
        value = module.core_helpers.team
      },
    ],
    var.openbao_helm_set_values,
  )

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # GKE MultiClusterIngress and MultiClusterService resources are managed only from
  # the fleet's config cluster.
  openbao_config_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_name == "pt-pneuma-us-east1-b"
  }

  # OpenBao's global MultiClusterService spans every platform-managed OpenBao cluster.
  openbao_multi_cluster_service_clusters = [
    for cluster_name, cluster_config in local.main.gke_clusters :
    {
      link = "${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}/${cluster_name}"
    }
    if cluster_config.team_key == module.core_helpers.team
  ]

  # Each cluster also gets a direct GKE Ingress endpoint, named with its zone prefix.
  openbao_zonal_hostname = "${local.zone}.${local.main.openbao_hostname}"

  # Region per cluster, parsed from the cluster name (e.g. "pt-pneuma-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-openbao-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
