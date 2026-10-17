# Google Compute Global Address Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/compute_global_address

resource "google_compute_global_address" "openbao_ingress" {
  for_each = local.gke_clusters

  labels  = module.core_helpers.labels
  name    = "openbao-${local.zone}"
  project = each.value.project_id
}

# Google DNS Record Set Resource
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/resources/dns_record_set

resource "google_dns_record_set" "openbao_zonal" {
  for_each = local.gke_clusters

  managed_zone = local.main.openbao_public_dns_zone_name
  name         = "${local.openbao_zonal_hostname}."
  project      = local.main.shared_vpc_host_project_id
  rrdatas      = [google_compute_global_address.openbao_ingress[each.key].address]
  ttl          = 300
  type         = "A"
}

# Helm Release Resource
# https://search.opentofu.org/provider/hashicorp/helm/latest/docs/resources/release

resource "helm_release" "openbao" {
  depends_on = [
    kubernetes_manifest.openbao_backendconfig,
  ]

  for_each = local.gke_clusters
  provider = helm.by_cluster[each.key]

  chart      = "openbao"
  name       = "openbao"
  namespace  = "${module.core_helpers.team}-openbao"
  repository = "https://openbao.github.io/openbao-helm"

  set = local.helm_set_values

  values = [
    file("${path.module}/helm/openbao.yml"),
    local.openbao_dynamic_helm_values
  ]

  version = var.openbao_version
}

# Kubernetes Ingress Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/ingress_v1

resource "kubernetes_ingress_v1" "openbao" {
  depends_on = [
    helm_release.openbao,
  ]

  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  metadata {
    annotations = {
      "kubernetes.io/ingress.allow-http"            = "false"
      "kubernetes.io/ingress.class"                 = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.openbao_ingress[each.key].name
      "networking.gke.io/managed-certificates"      = kubernetes_manifest.openbao_managed_certificate[each.key].manifest.metadata.name
      "networking.gke.io/v1beta1.FrontendConfig"    = kubernetes_manifest.openbao_frontendconfig[each.key].manifest.metadata.name
    }

    name      = "openbao"
    namespace = "${module.core_helpers.team}-openbao"
  }

  spec {
    rule {
      host = local.openbao_zonal_hostname

      http {
        path {
          backend {
            service {
              name = "openbao"

              port {
                number = 8200
              }
            }
          }

          path      = "/"
          path_type = "Prefix"
        }
      }
    }
  }

  wait_for_load_balancer = true
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "openbao_backendconfig" {
  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "cloud.google.com/v1"
    kind       = "BackendConfig"
    metadata = {
      name      = "openbao-backend"
      namespace = "${module.core_helpers.team}-openbao"
    }
    spec = {
      healthCheck = {
        checkIntervalSec = 5
        healthyThreshold = 1
        port             = 8200
        # Keep standby nodes healthy while sealed or uninitialized nodes remain unhealthy.
        requestPath        = "/v1/sys/health?standbyok=true"
        timeoutSec         = 3
        type               = "HTTP"
        unhealthyThreshold = 2
      }
      securityPolicy = {
        name = local.main.shared_ingress_policy_name
      }
    }
  }
}

resource "kubernetes_manifest" "openbao_frontendconfig" {
  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.gke.io/v1beta1"
    kind       = "FrontendConfig"
    metadata = {
      name      = "openbao-frontend"
      namespace = "${module.core_helpers.team}-openbao"
    }
    spec = {
      redirectToHttps = {
        enabled = true
      }
      sslPolicy = local.main.shared_ingress_policy_name
    }
  }
}

resource "kubernetes_manifest" "openbao_managed_certificate" {
  for_each = local.gke_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "openbao-zonal-tls"
      namespace = "${module.core_helpers.team}-openbao"
    }
    spec = {
      domains = [local.openbao_zonal_hostname]
    }
  }
}

resource "kubernetes_manifest" "openbao_mci" {
  depends_on = [
    kubernetes_manifest.openbao_mcs,
  ]

  for_each = local.openbao_config_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "MultiClusterIngress"
    metadata = {
      annotations = {
        "networking.gke.io/frontend-config"  = kubernetes_manifest.openbao_frontendconfig[each.key].manifest.metadata.name
        "networking.gke.io/pre-shared-certs" = local.main.openbao_mci_ssl_certificate_name
        "networking.gke.io/static-ip"        = local.main.openbao_mci_global_address
      }
      name      = "openbao-mci"
      namespace = "${module.core_helpers.team}-openbao"
    }
    spec = {
      template = {
        spec = {
          backend = {
            serviceName = kubernetes_manifest.openbao_mcs[each.key].manifest.metadata.name
            servicePort = 8200
          }
          rules = [
            {
              host = local.main.openbao_hostname
              http = {
                paths = [
                  {
                    backend = {
                      serviceName = kubernetes_manifest.openbao_mcs[each.key].manifest.metadata.name
                      servicePort = 8200
                    }
                    path = "/"
                  }
                ]
              }
            }
          ]
        }
      }
    }
  }
}

resource "kubernetes_manifest" "openbao_mcs" {
  depends_on = [
    helm_release.openbao,
  ]

  for_each = local.openbao_config_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "MultiClusterService"
    metadata = {
      annotations = {
        "cloud.google.com/backend-config" = jsonencode({ "default" = kubernetes_manifest.openbao_backendconfig[each.key].manifest.metadata.name })
        "cloud.google.com/neg"            = jsonencode({ "ingress" = true })
      }
      name      = "openbao-mcs"
      namespace = "${module.core_helpers.team}-openbao"
    }
    spec = {
      clusters = local.openbao_multi_cluster_service_clusters
      template = {
        spec = {
          ports = [
            {
              name       = "http"
              port       = 8200
              protocol   = "TCP"
              targetPort = 8200
            }
          ]
          selector = {
            "app.kubernetes.io/instance" = "openbao"
            "app.kubernetes.io/name"     = "openbao"
            component                    = "server"
          }
        }
      }
    }
  }
}
