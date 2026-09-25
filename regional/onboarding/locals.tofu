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
  # Every team's namespaces — including pneuma's own — are prefixed with the team key
  # (e.g. "openbao" on pt-kryptos becomes "pt-kryptos-openbao", "istio-test" on pt-pneuma
  # becomes "pt-pneuma-istio-test") matching the prefixed keys in the main workspace's
  # workload_identity_service_account_emails output. The prefix also ensures Istio namespace
  # sameness works: the stub Service on the pneuma gateway cluster lives in the same prefixed
  # namespace, so Istio multi-primary discovery merges remote endpoints automatically. Prefixing
  # uniformly (with no platform-team exception) lets pneuma dogfood the model exactly like a
  # member team.
  #
  # The pinned pt-arche-google-kubernetes-engine onboarding module only supports the legacy
  # "istio-injection" sidecar label — it has no ambient-mode label of its own yet. Mapping
  # mesh_enabled to "enabled" would turn on sidecar injection (which Istio prioritizes over
  # ambient when both are present), defeating the ambient-only objective, so we always pass
  # "disabled" here regardless of mesh_enabled. True ambient enrollment (the
  # istio.io/dataplane-mode=ambient label) requires adding that label to the onboarding
  # module itself, which is out of scope for this change — tracked as a follow-up against
  # pt-arche-google-kubernetes-engine.
  namespaces = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      for namespace_name, namespace in try(module.core_helpers.teams[cluster_config.team_key].platform_managed_project.kubernetes_engine_namespaces, {}) :
      "${cluster_config.team_key}-${namespace_name}" => {
        google_service_account = "${cluster_config.team_key}-github@${local.main.shared_vpc_host_project_id}.iam.gserviceaccount.com"
        istio_injection        = "disabled"
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
