# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine_onboarding" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine//regional/onboarding?ref=f56d2d830d0cc4f690c1791de46bc683fe2fa2b6" # v0.2.7

  namespaces                               = var.kubernetes_engine_namespaces
  project                                  = data.terraform_remote_state.regional.outputs.project_id
  workload_identity_service_account_emails = data.terraform_remote_state.main.outputs.kubernetes_engine_workload_identity_service_account_emails
}
