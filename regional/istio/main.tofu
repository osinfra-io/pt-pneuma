# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/opentofu-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/opentofu-kubernetes-istio//regional?ref=a325290911bdb8085ea29ff922d2e00f00834f4a" # v0.2.0

  artifact_registry          = "us-docker.pkg.dev/pt-corpus-tf16-prod/pt-docker-virtual"
  cluster_prefix             = "pt-pneuma"
  enable_istio_gateway       = true
  gateway_cpu_limits         = var.kubernetes_istio_gateway_cpu_limits
  gateway_cpu_requests       = var.kubernetes_istio_gateway_cpu_requests
  gateway_dns                = var.kubernetes_istio_gateway_dns
  gateway_mci_global_address = local.main.kubernetes_istio_gateway_mci_global_address
  gateway_memory_limits      = var.kubernetes_istio_gateway_memory_limits
  gateway_memory_requests    = var.kubernetes_istio_gateway_memory_requests
  labels                     = module.helpers.labels

  multi_cluster_service_clusters = [
    {
      "link" = "us-east1/pt-pneuma-us-east1-b"
    },
    {
      "link" = "us-east4/pt-pneuma-us-east4-a"
    }
  ]

  pilot_cpu_limits                            = var.kubernetes_istio_pilot_cpu_limits
  pilot_cpu_requests                          = var.kubernetes_istio_pilot_cpu_requests
  pilot_memory_limits                         = var.kubernetes_istio_pilot_memory_limits
  pilot_memory_requests                       = var.kubernetes_istio_pilot_memory_requests
  project                                     = data.google_project.this.project_id
  proxy_cpu_limits                            = var.kubernetes_istio_proxy_cpu_limits
  proxy_cpu_requests                          = var.kubernetes_istio_proxy_cpu_requests
  proxy_memory_limits                         = var.kubernetes_istio_proxy_memory_limits
  proxy_memory_requests                       = var.kubernetes_istio_proxy_memory_requests
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
}
