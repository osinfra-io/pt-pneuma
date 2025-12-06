# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_regional" {
  for_each = local.gke_clusters
  source   = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional?ref=e67d2b9113d150efd7a68bb599795343f9e3620c" # v0.2.5

  cluster_prefix                = "plt"
  cluster_secondary_range_name  = "k8s-secondary-pods"
  enable_deletion_protection    = false
  enable_gke_hub_host           = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships           = lookup(each.value, "gke_hub_memberships", {})
  labels                        = module.helpers.labels
  master_ipv4_cidr_block        = var.kubernetes_engine_master_ipv4_cidr_block
  network                       = var.kubernetes_engine_network
  node_pools                    = lookup(each.value, "node_pools", {})
  project                       = local.main.project_id
  resource_labels               = module.helpers.labels
  services_secondary_range_name = "k8s-secondary-services"
  subnet                        = local.subnet
  vpc_host_project_id           = var.kubernetes_engine_vpc_host_project_id
}
