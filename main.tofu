# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=e68649ce530ca7e9f435545e476b220a76189e47" # v0.4.0

  for_each = local.teams_with_clusters

  gke_fleet_host_project_id = each.key == "pt-pneuma" ? "" : local.team_project_ids["pt-pneuma"]
  labels                    = module.core_helpers.labels
  namespaces                = local.gke_namespaces_by_team[each.key]
  project                   = local.team_project_ids[each.key]
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=bb00d8bd52c54cbdde002d88808df07b035e6c1c" # v0.3.0

  for_each = local.teams_with_clusters
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=7734e2e2846fa1d872c1f58bdab6ba964530c3e9" # v0.4.0

  for_each = local.teams_with_clusters

  gateway_dns = local.gateway_dns_by_team[each.key]
  labels      = module.core_helpers.labels
  project     = local.team_project_ids[each.key]
}
