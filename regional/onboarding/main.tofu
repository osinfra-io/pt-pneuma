# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=17ec48e935e9be141990413419e61161527ac60c" # v0.4.5

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  namespaces                               = local.namespaces[each.key]
  project                                  = each.value.project_id
  workload_identity_service_account_emails = local.main.kubernetes_engine_workload_identity_service_account_emails[each.value.team_key]
}
