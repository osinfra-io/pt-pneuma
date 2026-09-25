# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=2791f635a9e191e2c441f8d7944fad7681fb0885" # Temporary pre-release pin (PR #182) — re-pin to a tagged release once merged

  for_each = local.gke_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  namespaces                               = local.namespaces[each.key]
  project                                  = each.value.project_id
  workload_identity_service_account_emails = local.main.kubernetes_engine_workload_identity_service_account_emails[each.value.team_key]
}
