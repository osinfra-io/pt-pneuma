# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=50122dfd99038d0c4e02e48fd175d62f8c6aae6e" # v0.4.0

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  cainjector_replicas                       = var.kubernetes_cert_manager_cainjector_replicas
  cainjector_resources_limits_cpu           = var.kubernetes_cert_manager_cainjector_resources_limits_cpu
  cainjector_resources_limits_memory        = var.kubernetes_cert_manager_cainjector_resources_limits_memory
  cainjector_resources_requests_cpu         = var.kubernetes_cert_manager_cainjector_resources_requests_cpu
  cainjector_resources_requests_memory      = var.kubernetes_cert_manager_cainjector_resources_requests_memory
  replicas                                  = var.kubernetes_cert_manager_replicas
  resources_limits_cpu                      = var.kubernetes_cert_manager_resources_limits_cpu
  resources_limits_memory                   = var.kubernetes_cert_manager_resources_limits_memory
  resources_requests_cpu                    = var.kubernetes_cert_manager_resources_requests_cpu
  resources_requests_memory                 = var.kubernetes_cert_manager_resources_requests_memory
  startupapicheck_resources_limits_cpu      = var.kubernetes_cert_manager_startupapicheck_resources_limits_cpu
  startupapicheck_resources_limits_memory   = var.kubernetes_cert_manager_startupapicheck_resources_limits_memory
  startupapicheck_resources_requests_cpu    = var.kubernetes_cert_manager_startupapicheck_resources_requests_cpu
  startupapicheck_resources_requests_memory = var.kubernetes_cert_manager_startupapicheck_resources_requests_memory
  webhook_replicas                          = var.kubernetes_cert_manager_webhook_replicas
  webhook_resources_limits_cpu              = var.kubernetes_cert_manager_webhook_resources_limits_cpu
  webhook_resources_limits_memory           = var.kubernetes_cert_manager_webhook_resources_limits_memory
  webhook_resources_requests_cpu            = var.kubernetes_cert_manager_webhook_resources_requests_cpu
  webhook_resources_requests_memory         = var.kubernetes_cert_manager_webhook_resources_requests_memory
}
