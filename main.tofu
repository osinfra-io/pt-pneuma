# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager?ref=a0f6efd73e0d807358290fab35309c1ae9299a77" # v0.2.0
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine?ref=ab31391eb90a38670c84af1119c271714b14bda3" # v0.3.1

  labels     = module.helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.kubernetes.project_id
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/opentofu-kubernetes-istio?ref=e6b14fa213f275e4b9081c5414a814d2e05e04ab" # v0.3.1

  gateway_dns = local.gateway_dns
  labels      = module.helpers.labels
  project     = data.google_project.kubernetes.project_id
}
