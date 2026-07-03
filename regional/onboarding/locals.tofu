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
  namespaces = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for namespace_name, namespace in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) :
      namespace_name => {
        google_service_account = data.google_service_account.github[cluster_config.team_key].email
        istio_injection        = namespace.istio_injection
      }
    }
  }

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # Distinct teams with a cluster in this zone — used to look up each team's GitHub
  # Actions service account from pt-corpus.
  teams_in_zone = toset([for cluster_config in local.gke_clusters : cluster_config.team_key])

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-onboarding-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
