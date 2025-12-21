# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Docker repositories with registry IAM members from team identity groups
  # Only created in us-east1-d region (multi-region repositories) when enabled via variable
  docker_repositories = var.enable_google_artifact_registries && contains(keys(local.main.team.identity_groups), "registry-readers") && contains(keys(local.main.team.identity_groups), "registry-writers") ? {
    pneuma = {
      registry_readers = [
        "group:${local.main.team.identity_groups["registry-readers"].email}"
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

  # Subnet name constructed from team, region, and zone
  subnet = "pt-pneuma-${module.helpers.region}-${module.helpers.zone}"
}
