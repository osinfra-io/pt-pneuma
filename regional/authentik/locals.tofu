# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Pneuma gateway clusters in this zone that receive a stateless Authentik server/worker.
  # Every instance points at the single shared Cloud SQL primary and shares the secret key
  # created in the main workspace, so together they form one logical identity provider.
  authentik_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  authentik_namespace = local.main.authentik_kubernetes_namespace

  authentik_secret_name = "authentik-env"

  authentik_server_replicas = module.core_helpers.env == "sb" ? 1 : 2

  authentik_server_resources_requests_cpu = module.core_helpers.env == "sb" ? "100m" : "200m"

  authentik_server_resources_requests_memory = module.core_helpers.env == "sb" ? "256Mi" : "512Mi"

  authentik_worker_replicas = 1

  authentik_worker_resources_requests_cpu = module.core_helpers.env == "sb" ? "50m" : "100m"

  authentik_worker_resources_requests_memory = module.core_helpers.env == "sb" ? "128Mi" : "256Mi"

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs (shared Cloud SQL host/name/user and shared secret env).
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-pneuma-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-authentik-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
