# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_regional" {
  for_each = local.gke_clusters
  source   = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional?ref=f56d2d830d0cc4f690c1791de46bc683fe2fa2b6" # v0.2.7

  cluster_prefix             = "plt"
  enable_deletion_protection = false
  enable_gke_hub_host        = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships        = lookup(each.value, "gke_hub_memberships", {})
  labels                     = module.helpers.labels
  master_ipv4_cidr_block     = var.kubernetes_engine_master_ipv4_cidr_block
  node_pools                 = lookup(each.value, "node_pools", {})
  project                    = local.main.project_id
  resource_labels            = module.helpers.labels
  subnet                     = local.subnet
  vpc_host_project_id        = var.kubernetes_engine_vpc_host_project_id
}
