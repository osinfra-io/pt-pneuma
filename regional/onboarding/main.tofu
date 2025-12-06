# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional/onboarding?ref=e67d2b9113d150efd7a68bb599795343f9e3620c" # v0.2.5

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.regional.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
