# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters aggregated from all teams
  gke_clusters = local.main.gke_clusters

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Subnet name constructed from team, region, and zone
  subnet = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
}
