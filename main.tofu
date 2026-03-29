# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "google_kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=4477108018add36dd477904df79ef01f5a3315d0" # v0.3.4

  labels     = module.core_helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.kubernetes.project_id
}

# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=51b9c4ce4933a31870c9ea5fd398f96d7674232f" # v0.2.2
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=eb4670328111e91d87296ff3338c9f04efaa9217" # v0.3.5

  gateway_dns = local.gateway_dns
  labels      = module.core_helpers.labels
  project     = data.google_project.kubernetes.project_id
}
