# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Subnet name constructed from team, region, and zone
  subnet = "pt-pneuma-${module.helpers.region}-${module.helpers.zone}"

  # GKE clusters aggregated from all teams
  gke_clusters = local.main.gke_clusters
}
