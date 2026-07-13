# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=4fd300aaef54116bfc057d6edbbcb4efed373c37" # v0.4.3

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  namespaces                               = local.namespaces[each.key]
  project                                  = each.value.project_id
  workload_identity_service_account_emails = local.main.kubernetes_engine_workload_identity_service_account_emails[each.value.team_key]
}
