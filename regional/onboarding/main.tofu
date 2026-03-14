# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=243d2a3fd369024c6e37fec8c3f43b3ff53113f4" # fix-missing-mcs-service-agent-binding

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.main.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
