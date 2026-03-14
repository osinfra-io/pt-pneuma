# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=ea72b0d648b5be9b403c0c2946a9022810e9f849" # v0.2.1
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=28e3b79b870028d241a3938323829d0500630a62" # fix-missing-mcs-service-agent-binding

  labels     = module.helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.kubernetes.project_id
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=58e5a5e78db17bf753f5bceb0406aa1e525b8b79" # fix-dns-auto-allocate-deprecation

  gateway_dns = local.gateway_dns
  labels      = module.helpers.labels
  project     = data.google_project.kubernetes.project_id
}
