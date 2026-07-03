# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=ce4808af45ecf771c0a6d05b7c6af829e64ea668" # v0.3.9

  for_each = local.teams_with_clusters

  labels     = module.core_helpers.labels
  namespaces = local.gke_namespaces_by_team[each.key]
  project    = local.team_project_ids[each.key]
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=cdfc86416878cf8ff489ebef2075bce544a2bb56" # v0.2.5

  for_each = local.teams_with_clusters
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=8eed62d605a258f8f9fe43b761d347251b08901a" # v0.3.8

  for_each = local.teams_with_clusters

  gateway_dns = local.gateway_dns_by_team[each.key]
  labels      = module.core_helpers.labels
  project     = local.team_project_ids[each.key]
}
