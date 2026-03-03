# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  # GKE clusters aggregated from all teams
  gke_clusters = local.main.gke_clusters

  # Main workspace outputs
  main = data.terraform_remote_state.main.outputs

  # Master CIDR for GKE control plane, sourced from the subnet definition in pt-logos
  master_ipv4_cidr_block = local.main.team.google_subnets[module.helpers.region][local.subnet].master_ipv4_cidr_block

  # Subnet name constructed from team, region, and zone
  subnet = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
}
