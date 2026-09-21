# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  gateway_auth_guardrail_allowed_groups = [
    "system:masters",
  ]

  gateway_auth_guardrail_allowed_users = distinct([
    local.gateway_auth_guardrail_platform_github_service_account_email,
    "serviceAccount:${local.gateway_auth_guardrail_platform_github_service_account_email}",
  ])

  gateway_auth_guardrail_platform_github_service_account_email = "pt-pneuma-github@${local.main.shared_vpc_host_project_id}.iam.gserviceaccount.com"

  gateway_auth_guardrail_protected_kinds = [
    {
      apiGroup = "networking.istio.io"
      kind     = "EnvoyFilter"
    },
    {
      apiGroup = "security.istio.io"
      kind     = "AuthorizationPolicy"
    },
    {
      apiGroup = "security.istio.io"
      kind     = "RequestAuthentication"
    },
  ]

  gateway_auth_guardrail_protected_namespaces = [
    local.main.authentik_kubernetes_namespace,
  ]

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name. Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
