# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_regional" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional?ref=89df0c51d977937743a2075605acdca2f69b90d2" # v0.6.0

  for_each = local.gke_clusters

  cluster_prefix              = each.value.team_key
  enable_deletion_protection  = false
  enable_gateway_api          = each.value.enable_gateway_api
  enable_gke_hub_host         = each.value.enable_gke_hub_host
  gke_hub_memberships         = each.value.gke_hub_memberships
  labels                      = module.core_helpers.labels
  node_pools                  = each.value.node_pools
  private_endpoint_subnetwork = each.value.private_endpoint_subnetwork
  project                     = each.value.project_id
  resource_labels             = module.core_helpers.labels
  subnet                      = each.key
  vpc_host_project_id         = local.main.shared_vpc_host_project_id
}
