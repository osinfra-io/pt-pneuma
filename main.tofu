# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager?ref=679825a8a8e19921c1674b2dafe58e54b7ae792b" # v0.2.1
}

# Google Kubernetes Engine Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-google-kubernetes-engine

module "kubernetes_engine" {
  source = "github.com/osinfra-io/pt-arche-google-kubernetes-engine?ref=da865402f50f151dc70550a2b3cc882932b3257e" # v0.3.2

  labels     = module.helpers.labels
  namespaces = var.kubernetes_engine_namespaces
  project    = data.google_project.kubernetes.project_id
}

# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio?ref=2765d3b14d66505a443629f13f1aa64040bce9c4" # v0.3.2

  gateway_dns = local.gateway_dns
  labels      = module.helpers.labels
  project     = data.google_project.kubernetes.project_id
}
