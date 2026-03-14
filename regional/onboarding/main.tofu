# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine//regional/onboarding?ref=28e3b79b870028d241a3938323829d0500630a62" # fix-missing-mcs-service-agent-binding

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.main.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
