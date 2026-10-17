# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=15e77d4b92128c754e251cf13ed212d00420601c" # v2.0.0

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  namespaces                               = local.namespaces[each.key]
  workload_identity_service_account_emails = local.main.kubernetes_engine_workload_identity_service_account_emails[each.value.team_key]
}
