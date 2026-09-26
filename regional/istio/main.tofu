# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional?ref=ba5ac611fb568268d400aa11741d8d62923cff43" # TEMP: PR #115 branch tip, re-pin after merge + tag

  for_each = local.gke_clusters

  providers = {
    google     = google
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  artifact_registry                           = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  cluster_prefix                              = each.value.team_key
  cni_cpu_requests                            = var.kubernetes_istio_cni_cpu_requests
  cni_memory_requests                         = var.kubernetes_istio_cni_memory_requests
  east_west_gateway_cpu_limits                = var.kubernetes_istio_east_west_gateway_cpu_limits
  east_west_gateway_cpu_requests              = var.kubernetes_istio_east_west_gateway_cpu_requests
  east_west_gateway_memory_limits             = var.kubernetes_istio_east_west_gateway_memory_limits
  east_west_gateway_memory_requests           = var.kubernetes_istio_east_west_gateway_memory_requests
  enable_istio_gateway                        = each.value.team_key == module.core_helpers.team
  gateway_autoscale_max                       = var.kubernetes_istio_gateway_autoscale_max
  gateway_autoscale_min                       = var.kubernetes_istio_gateway_autoscale_min
  gateway_cpu_limits                          = var.kubernetes_istio_gateway_cpu_limits
  gateway_cpu_requests                        = var.kubernetes_istio_gateway_cpu_requests
  gateway_dns                                 = each.value.team_key == module.core_helpers.team ? local.gateway_dns[each.key] : {}
  gateway_mci_global_address                  = try(local.main.kubernetes_istio_gateway_mci_global_address[each.value.team_key], null)
  gateway_memory_limits                       = var.kubernetes_istio_gateway_memory_limits
  gateway_memory_requests                     = var.kubernetes_istio_gateway_memory_requests
  labels                                      = module.core_helpers.labels
  mesh_config_extension_providers             = local.istio_mesh_config_extension_providers[each.key]
  mesh_config_service_settings                = local.istio_mesh_config_service_settings[each.key]
  multi_cluster_service_clusters              = local.multi_cluster_service_clusters[each.key]
  pilot_autoscale_max                         = var.kubernetes_istio_pilot_autoscale_max
  pilot_autoscale_min                         = var.kubernetes_istio_pilot_autoscale_min
  pilot_cpu_limits                            = var.kubernetes_istio_pilot_cpu_limits
  pilot_cpu_requests                          = var.kubernetes_istio_pilot_cpu_requests
  pilot_memory_limits                         = var.kubernetes_istio_pilot_memory_limits
  pilot_memory_requests                       = var.kubernetes_istio_pilot_memory_requests
  pilot_replica_count                         = var.kubernetes_istio_pilot_replica_count
  project                                     = each.value.project_id
  proxy_cpu_limits                            = var.kubernetes_istio_proxy_cpu_limits
  proxy_cpu_requests                          = var.kubernetes_istio_proxy_cpu_requests
  proxy_memory_limits                         = var.kubernetes_istio_proxy_memory_limits
  proxy_memory_requests                       = var.kubernetes_istio_proxy_memory_requests
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
  ztunnel_cpu_limits                          = var.kubernetes_istio_ztunnel_cpu_limits
  ztunnel_cpu_requests                        = var.kubernetes_istio_ztunnel_cpu_requests
  ztunnel_memory_limits                       = var.kubernetes_istio_ztunnel_memory_limits
  ztunnel_memory_requests                     = var.kubernetes_istio_ztunnel_memory_requests
}

# Kubernetes Deployment Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/deployment_v1

resource "kubernetes_deployment_v1" "datadog_aap_extproc" {
  depends_on = [
    module.kubernetes_istio
  ]

  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  metadata {
    labels = {
      app                          = "datadog-aap-extproc"
      "tags.datadoghq.com/env"     = module.core_helpers.environment
      "tags.datadoghq.com/service" = "istio-gateway"
    }

    name      = "datadog-aap-extproc-deployment"
    namespace = "istio-ingress"
  }

  spec {
    selector {
      match_labels = {
        app = "datadog-aap-extproc"
      }
    }

    template {
      metadata {
        annotations = {
          "apm.datadoghq.com/env" = jsonencode({
            DD_ENV     = module.core_helpers.environment
            DD_SERVICE = "istio-gateway"
          })
        }

        labels = {
          "admission.datadoghq.com/enabled" = "true"
          app                               = "datadog-aap-extproc"
          "tags.datadoghq.com/env"          = module.core_helpers.environment
          "tags.datadoghq.com/service"      = "istio-gateway"
        }
      }

      spec {
        container {
          env {
            name  = "DD_APPSEC_WAF_TIMEOUT"
            value = "10000"
          }

          env {
            name = "DD_ENV"
            value_from {
              field_ref {
                field_path = "metadata.labels['tags.datadoghq.com/env']"
              }
            }
          }

          env {
            name = "DD_SERVICE"
            value_from {
              field_ref {
                field_path = "metadata.labels['tags.datadoghq.com/service']"
              }
            }
          }

          image             = "ghcr.io/datadog/dd-trace-go/service-extensions-callout:v2.2.2"
          image_pull_policy = "Always"
          name              = "datadog-aap-extproc-container"

          liveness_probe {
            http_get {
              path = "/"
              port = "health"
            }

            initial_delay_seconds = 15
            period_seconds        = 20
          }

          port {
            container_port = 443
            name           = "grpc"
          }

          port {
            container_port = 80
            name           = "health"
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "health"
            }

            initial_delay_seconds = 5
            period_seconds        = 10
          }

          resources {
            limits = {
              cpu    = "100m"
              memory = "256Mi"
            }

            requests = {
              cpu    = "50m"
              memory = "128Mi"
            }
          }

          security_context {
            allow_privilege_escalation = false

            capabilities {
              drop = ["ALL"]
            }
          }
        }
      }
    }
  }
}

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "datadog_aap_extproc" {
  depends_on = [
    module.kubernetes_istio
  ]

  for_each = local.gateway_clusters

  provider = kubernetes.by_cluster[each.key]

  metadata {
    labels = {
      app = "datadog-aap-extproc"
    }

    name      = "datadog-aap-extproc-service"
    namespace = "istio-ingress"
  }

  spec {
    port {
      name        = "grpc"
      port        = 443
      protocol    = "TCP"
      target_port = "grpc"
    }

    selector = {
      app = "datadog-aap-extproc"
    }

    type = "ClusterIP"
  }
}
