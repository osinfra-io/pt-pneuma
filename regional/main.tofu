# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_regional" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional?ref=6ef17e0c4a5539daf835b5f793d296687544903e" # v0.5.0

  for_each = local.gke_clusters

  cluster_prefix              = each.value.team_key
  enable_deletion_protection  = false
  enable_gateway_api          = each.value.enable_gateway_api
  enable_gke_hub_host         = lookup(each.value, "enable_gke_hub_host", false)
  gke_hub_memberships         = lookup(each.value, "gke_hub_memberships", {})
  labels                      = module.core_helpers.labels
  node_pools                  = lookup(each.value, "node_pools", {})
  private_endpoint_subnetwork = "${each.key}-master"
  project                     = each.value.project_id
  resource_labels             = module.core_helpers.labels
  subnet                      = each.key
  vpc_host_project_id         = local.main.shared_vpc_host_project_id
}
