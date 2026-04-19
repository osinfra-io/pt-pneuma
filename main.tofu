# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=fdb89acac1442f89dc69557f218dbc430ea1001a" # v0.3.6

  labels     = module.core_helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.platform_managed.project_id
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=ed05c50c5bb9c7213e32d8601780fe604585c049" # v0.2.4
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=7b66900fc6a6d5fe31e31fa2dd406f2f63f79703" # v0.3.7

  gateway_dns = local.gateway_dns
  labels      = module.core_helpers.labels
  project     = data.google_project.platform_managed.project_id
}
