# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_regional" {
  for_each = local.gke_clusters

  cluster_prefix             = module.core_helpers.team
  enable_deletion_protection = false
  enable_gke_hub_host        = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships        = lookup(each.value, "gke_hub_memberships", {})
  labels                     = module.core_helpers.labels
  master_ipv4_cidr_block     = lookup(each.value, "subnet", {}).master_ipv4_cidr_block
  node_pools                 = lookup(each.value, "node_pools", {})
  project                    = local.main.project_id
  resource_labels            = module.core_helpers.labels
  source                     = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional?ref=eeb68eab5e63d608eb9271064683b17a53f6cca8" # v0.3.3
  subnet                     = local.subnet
  vpc_host_project_id        = local.main.shared_vpc_host_project_id
}
