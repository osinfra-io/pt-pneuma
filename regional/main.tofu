# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine_regional" {
  source   = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional?ref=da865402f50f151dc70550a2b3cc882932b3257e" # v0.3.2
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
