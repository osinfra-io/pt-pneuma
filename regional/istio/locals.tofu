# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Gateway DNS per cluster. Pneuma (gateway) clusters create zonal A records for ALL
  # teams — because every team's DNS routes through pneuma's single ingress gateway.
  # Member team clusters get nothing (their traffic arrives via the mesh, not a local LB).
  gateway_dns = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config.team_key == module.core_helpers.team ? {
      for team_key, team_dns in local.main.gateway_dns :
      "${regex("(us-[a-z0-9]+-[a-z])$", cluster_name)[0]}.${one(keys(team_dns))}" => one(values(team_dns))
      if length(team_dns) > 0
    } : {}
  }

  # GKE clusters in this zone that have the Istio gateway enabled (platform team only).
  # Used for resources that are gateway-specific (e.g. Datadog AAP extproc).
  gateway_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => cluster_config
    if cluster_config.team_key == module.core_helpers.team
  }

  # GKE clusters in this zone — the subset that actually receives the add-on.
  # The zone is parsed from the workspace name (static context safe).
  gke_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}")
  }

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  istio_mesh_configs = {
    for cluster_name in keys(local.gateway_clusters) :
    cluster_name => yamlencode({
      accessLogFile = "/dev/stdout"

      defaultConfig = {
        proxyMetadata = {
          ECC_CURVE               = "P256"
          ECC_SIGNATURE_ALGORITHM = "ECDSA"
          ISTIO_META_DNS_CAPTURE  = "true"
        }
      }

      extensionProviders = [
        {
          envoyExtAuthzHttp = {
            failOpen = false

            headersToDownstreamOnAllow = [
              "cookie",
            ]

            headersToDownstreamOnDeny = [
              "content-type",
              "set-cookie",
            ]

            headersToUpstreamOnAllow = [
              "set-cookie",
              "x-authentik-*",
            ]

            includeRequestHeadersInCheck = [
              "cookie",
            ]

            pathPrefix = local.authentik_outpost_path_prefix
            port       = try(data.terraform_remote_state.authentik_config.outputs.outpost_service_port, local.authentik_outpost_service_port)
            service    = "${try(data.terraform_remote_state.authentik_config.outputs.outpost_service_name, local.authentik_outpost_service_name)}.${try(data.terraform_remote_state.authentik_config.outputs.outpost_namespace, local.authentik_outpost_namespace)}.svc.cluster.local"
          }

          name = local.authentik_extension_provider_name
        }
      ]
    })
  }

  # Multi-cluster service links per cluster — the set of the owning team's clusters
  # (across all zones) that participate in the Istio multi-cluster mesh.
  multi_cluster_service_clusters = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => [
      for peer_name, peer_config in local.main.gke_clusters :
      {
        link = "${regex("(us-[a-z0-9]+)-[a-z]$", peer_name)[0]}/${peer_name}"
      }
      if peer_config.team_key == cluster_config.team_key
    ]
  }

  authentik_extension_provider_name = "authentik"

  # Well-known Authentik managed proxy outpost coordinates used as fallbacks for the ext_authz
  # provider, since the Istio mesh config is applied before the authentik-config workspace exists
  # (its remote state is empty on first apply). Once authentik-config is applied, its authoritative
  # outputs take precedence via try().
  authentik_outpost_namespace    = "authentik"
  authentik_outpost_path_prefix  = "/outpost.goauthentik.io/auth/envoy"
  authentik_outpost_service_name = "ak-outpost-gateway"
  authentik_outpost_service_port = 9000

  # Region per cluster, parsed from the cluster name (e.g. "pt-kryptos-us-east1-b" → "us-east1").
  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-istio-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
