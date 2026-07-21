# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters in this zone — the subset that actually receives namespaces.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Namespaces per cluster, derived from Logos team data. The team's GitHub Actions
  # service account (from pt-corpus) is bound as the namespace administrator.
  # Member team namespaces are prefixed with the team key (e.g. "openbao" on pt-kryptos
  # becomes "pt-kryptos-openbao") matching the prefixed keys in the main workspace's
  # workload_identity_service_account_emails output. The prefix also ensures Istio namespace
  # sameness works: the stub Service on the pneuma gateway cluster lives in the same prefixed
  # namespace, so Istio multi-primary discovery merges remote endpoints automatically.
  # route_prefix (the team's subdomain label) is applied to every namespace so the arche
  # onboarding module can add the osinfra.io/route-prefix label that lets the namespace
  # attach HTTPRoutes to the team's shared gateway listener.
  namespaces = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for namespace_name, namespace in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) :
      (cluster_config.team_key != module.core_helpers.team ? "${cluster_config.team_key}-${namespace_name}" : namespace_name) => {
        google_service_account = "${cluster_config.team_key}-github@${local.main.shared_vpc_host_project_id}.iam.gserviceaccount.com"
        istio_injection        = namespace.istio_injection
        route_prefix           = module.core_helpers.teams[cluster_config.team_key].route_prefix
      }
    }
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-onboarding-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
