# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/opentofu-kubernetes-cert-manager?ref=6d8932f1f50f2688a2132feab870c9fef3b4e709" # v0.1.7
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-google-kubernetes-engine

module "kubernetes_engine" {
  source = "github.com/osinfra-io/opentofu-google-kubernetes-engine?ref=f56d2d830d0cc4f690c1791de46bc683fe2fa2b6" # v0.2.7

  labels     = module.helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.kubernetes[0].project_id
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/opentofu-kubernetes-istio?ref=a325290911bdb8085ea29ff922d2e00f00834f4a" # v0.2.0

  gateway_dns = local.gateway_dns
  labels      = module.helpers.labels
  project     = data.google_project.kubernetes[0].project_id
}
