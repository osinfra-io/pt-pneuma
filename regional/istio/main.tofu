# Kubernetes Istio Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-istio

module "kubernetes_istio" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-istio//regional?ref=8b7defdd59d1940ca551daac06fbd4932470b5e8" # v0.5.0

  for_each = local.gke_clusters

  providers = {
    google     = google
    helm       = helm.by_cluster[each.key]
    kubernetes = kubernetes.by_cluster[each.key]
  }

  artifact_registry          = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
  cluster_prefix             = each.value.team_key
  enable_istio_gateway       = each.value.team_key == module.core_helpers.team
  gateway_cpu_limits         = var.kubernetes_istio_gateway_cpu_limits
  gateway_cpu_requests       = var.kubernetes_istio_gateway_cpu_requests
  gateway_dns                = each.value.team_key == module.core_helpers.team ? local.gateway_dns[each.key] : {}
  gateway_mci_global_address = try(local.main.kubernetes_istio_gateway_mci_global_address[each.value.team_key], null)
  gateway_memory_limits      = var.kubernetes_istio_gateway_memory_limits
  gateway_memory_requests    = var.kubernetes_istio_gateway_memory_requests
  labels                     = module.core_helpers.labels

  multi_cluster_service_clusters = local.multi_cluster_service_clusters[each.key]

  pilot_cpu_limits                            = var.kubernetes_istio_pilot_cpu_limits
  pilot_cpu_requests                          = var.kubernetes_istio_pilot_cpu_requests
  pilot_memory_limits                         = var.kubernetes_istio_pilot_memory_limits
  pilot_memory_requests                       = var.kubernetes_istio_pilot_memory_requests
  project                                     = each.value.project_id
  proxy_cpu_limits                            = var.kubernetes_istio_proxy_cpu_limits
  proxy_cpu_requests                          = var.kubernetes_istio_proxy_cpu_requests
  proxy_memory_limits                         = var.kubernetes_istio_proxy_memory_limits
  proxy_memory_requests                       = var.kubernetes_istio_proxy_memory_requests
  tls_self_signed_cert_cert_manager_root_cert = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert
  tls_self_signed_cert_cert_manager_root_key  = local.main.kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key
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
          "sidecar.istio.io/inject" = "false"
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

# Kubernetes Labels Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/labels

resource "kubernetes_labels" "default_namespace_istio_injection" {
  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  api_version = "v1"
  kind        = "Namespace"

  labels = {
    "istio-injection" = "disabled"
  }

  metadata {
    name = "default"
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
