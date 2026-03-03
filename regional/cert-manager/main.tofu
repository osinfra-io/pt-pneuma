# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager//regional?ref=a0f6efd73e0d807358290fab35309c1ae9299a77" # v0.2.0

  artifact_registry = "us-docker.pkg.dev/${data.terraform_remote_state.main.outputs.shared_vpc_host_project_id}/${module.helpers.team}-virtual"
}
