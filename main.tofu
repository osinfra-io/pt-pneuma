# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=ce4808af45ecf771c0a6d05b7c6af829e64ea668" # v0.3.9

  labels     = module.core_helpers.labels
  namespaces = local.gke_namespaces
  project    = data.google_project.platform_managed.project_id
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=cdfc86416878cf8ff489ebef2075bce544a2bb56" # v0.2.5
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=8eed62d605a258f8f9fe43b761d347251b08901a" # v0.3.8

  gateway_dns = local.gateway_dns
  labels      = module.core_helpers.labels
  project     = data.google_project.platform_managed.project_id
}
