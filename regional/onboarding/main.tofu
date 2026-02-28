# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional/onboarding?ref=ab31391eb90a38670c84af1119c271714b14bda3" # v0.3.1

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.main.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
