# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_regional" {
  source   = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional?ref=ab31391eb90a38670c84af1119c271714b14bda3" # v0.3.1
  for_each = local.gke_clusters

  cluster_prefix             = module.helpers.team
  enable_deletion_protection = false
  enable_gke_hub_host        = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships        = lookup(each.value, "gke_hub_memberships", {})
  labels                     = module.helpers.labels
  master_ipv4_cidr_block     = lookup(each.value, "subnet", {}).master_ipv4_cidr_block
  node_pools                 = lookup(each.value, "node_pools", {})
  project                    = local.main.project_id
  resource_labels            = module.helpers.labels
  subnet                     = local.subnet
  vpc_host_project_id        = local.main.shared_vpc_host_project_id
}
