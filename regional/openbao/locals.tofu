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

  # Values that depend on main workspace outputs: the Workload Identity binding for the OpenBao
  # ServiceAccount and the Raft config (the chart default with TLS enabled plus the gcpckms auto-unseal stanza).
  openbao_dynamic_helm_values = yamlencode({
    server = {
      ha = {
        raft = {
          config = <<-EOT
            ui = true

            listener "tcp" {
              address = "[::]:8200"
              cluster_address = "[::]:8201"
              tls_cert_file = "/openbao/userconfig/openbao-tls/tls.crt"
              tls_key_file = "/openbao/userconfig/openbao-tls/tls.key"
            }

            seal "gcpckms" {
              crypto_key = "${local.main.openbao_kms_seal.crypto_key}"
              key_ring   = "${local.main.openbao_kms_seal.key_ring}"
              project    = "${local.main.openbao_kms_seal.project}"
              region     = "${local.main.openbao_kms_seal.region}"
            }

            storage "raft" {
              path = "/openbao/data"
            }

            service_registration "kubernetes" {}
          EOT
        }
      }

      serviceAccount = {
        annotations = {
          "iam.gke.io/gcp-service-account" = local.main.openbao_kms_service_account_email
        }

        name = "openbao"
      }
    }
  })

  # SANs for the pod certificate: the external hostnames, every in-cluster name clients and Raft peers
  # use, and loopback for the in-pod bao CLI and probes.
  openbao_tls_dns_names = [
    local.main.openbao_hostname,
    local.openbao_zonal_hostname,
    "*.openbao-internal",
    "*.openbao-internal.${module.core_helpers.team}-openbao.svc.cluster.local",
    "openbao",
    "openbao-active",
    "openbao-active.${module.core_helpers.team}-openbao.svc.cluster.local",
    "openbao.${module.core_helpers.team}-openbao",
    "openbao.${module.core_helpers.team}-openbao.svc",
    "openbao.${module.core_helpers.team}-openbao.svc.cluster.local",
  ]

  # OpenBao's global MultiClusterService spans every platform-managed OpenBao cluster.
  openbao_multi_cluster_service_clusters = [
    for cluster_name, cluster_config in local.main.gke_clusters :
    {
      link = "${regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]}/${cluster_name}"
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

  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"

  # This deployment zone, parsed from the workspace name (e.g.
  # "us-east1-b-openbao-non-production" → "us-east1-b"). Static context safe.
  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
