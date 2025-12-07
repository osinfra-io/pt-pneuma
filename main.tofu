# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager?ref=6d8932f1f50f2688a2132feab870c9fef3b4e709" # v0.1.7
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine?ref=e67d2b9113d150efd7a68bb599795343f9e3620c" # v0.2.5

  labels                     = module.helpers.labels
  namespaces                 = var.kubernetes_engine_namespaces
  project                    = data.google_project.kubernetes.project_id
  shared_vpc_host_project_id = data.google_project.shared_vpc_host.project_id
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/opentofu-kubernetes-istio?ref=a325290911bdb8085ea29ff922d2e00f00834f4a" # v0.2.0

  gateway_dns = var.kubernetes_istio_gateway_dns
  labels      = module.helpers.labels
  project     = data.google_project.kubernetes.project_id
}
