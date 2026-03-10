# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=da865402f50f151dc70550a2b3cc882932b3257e" # v0.3.2

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.main.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
