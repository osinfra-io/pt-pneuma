# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine_onboarding" {
  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.main.outputs.project_id
  source                                   = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=4477108018add36dd477904df79ef01f5a3315d0" # v0.3.4
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
