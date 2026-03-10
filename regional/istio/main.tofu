# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional?ref=2765d3b14d66505a443629f13f1aa64040bce9c4" # v0.3.2

  artifact_registry          = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.helpers.team}-virtual"
  cluster_prefix             = module.helpers.team
  enable_istio_gateway       = true
  gateway_cpu_limits         = var.kubernetes_istio_gateway_cpu_limits
  gateway_cpu_requests       = var.kubernetes_istio_gateway_cpu_requests
  gateway_dns                = local.gateway_dns
  gateway_mci_global_address = try(local.main.kubernetes_istio_gateway_mci_global_address, null)
  gateway_memory_limits      = var.kubernetes_istio_gateway_memory_limits
  gateway_memory_requests    = var.kubernetes_istio_gateway_memory_requests
  labels                     = module.helpers.labels

  multi_cluster_service_clusters = local.multi_cluster_service_clusters

  pilot_cpu_limits                            = var.kubernetes_istio_pilot_cpu_limits
  pilot_cpu_requests                          = var.kubernetes_istio_pilot_cpu_requests
  pilot_memory_limits                         = var.kubernetes_istio_pilot_memory_limits
  pilot_memory_requests                       = var.kubernetes_istio_pilot_memory_requests
  project                                     = data.terraform_remote_state.main.outputs.project_id
  proxy_cpu_limits                            = var.kubernetes_istio_proxy_cpu_limits
  proxy_cpu_requests                          = var.kubernetes_istio_proxy_cpu_requests
  proxy_memory_limits                         = var.kubernetes_istio_proxy_memory_limits
  proxy_memory_requests                       = var.kubernetes_istio_proxy_memory_requests
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
