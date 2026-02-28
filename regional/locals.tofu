# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Docker repositories with registry IAM members from team identity groups
  # Only created in us-east1-d region (multi-region repositories) when enabled via variable
  docker_repositories = var.enable_google_artifact_registries && contains(keys(local.main.team.identity_groups), "registry-readers") && contains(keys(local.main.team.identity_groups), "registry-writers") ? {
    pt-pneuma = {
      registry_readers = [
        "group:${local.main.team.identity_groups["registry-readers"].email}",
        "serviceAccount:${local.main.project_number}-compute@developer.gserviceaccount.com"
      ]

      registry_writers = [
        "group:${local.main.team.identity_groups["registry-writers"].email}"
      ]
    }
  } : {}

  # GKE clusters aggregated from all teams
  gke_clusters = local.main.gke_clusters

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Master CIDR for GKE control plane, sourced from the subnet definition in pt-logos
  master_ipv4_cidr_block = local.main.team.google_subnets[module.helpers.region][local.subnet].master_ipv4_cidr_block

  # Subnet name constructed from team, region, and zone
  subnet = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
}
