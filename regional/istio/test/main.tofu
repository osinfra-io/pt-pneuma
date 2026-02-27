# Datadog Synthetics Test Resource
# https://search.opentofu.org/provider/opentofu/datadog/latest/resources/synthetics_test

resource "datadog_synthetics_test" "this" {
  for_each = local.datadog_synthetic_tests

  assertion {
    operator = "is"
    target   = "200"
    type     = "statusCode"
  }

  assertion {
    operator = "lessThan"
    target   = 1000
    type     = "responseTime"
  }

  locations = each.value.locations
  message   = each.value.message
  name      = "${each.value.name} ${each.value.region} ${module.helpers.environment}"

  options_list {
    monitor_priority = each.value.message_priority

    retry {
      count    = 2
      interval = 120
    }

    tick_every = 300
  }

  request_definition {
    method = "GET"
    url    = each.value.url
  }

  request_headers = each.value.region == "global" ? {} : {
    Body = "services-${each.value.region}"
  }

  status  = each.value.status
  subtype = "http"

  tags = [
    "env:${module.helpers.environment}",
    "region:${each.value.region}",
    "service:${each.value.service}",
    "team:${module.helpers.team}"
  ]

  type = "api"
}

# Kubernetes Deployment Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/deployment_v1

# This is a simple deployment that is used to get cluster status information and test end-to-end connectivity to the cluster
# through Datadog synthetic tests.

resource "kubernetes_deployment_v1" "istio_test" {
  # Minimize the admission of containers with the NET_RAW capability
  # checkov:skip=CKV_K8S_28: This needs some additional investigation

  # Apply security context to your pods, deployments and daemon_set
  # checkov:skip=CKV_K8S_29: A user is set in the container and we do not need to override it

  # Apply security context to your pods and containers
  # checkov:skip=CKV_K8S_30: A user is set in the container and we do not need to override it

  # Image should use digest
  # checkov:skip=CKV_K8S_43: We are using the image tag for the deployment

  metadata {
    labels = {
      "tags.datadoghq.com/env"     = module.helpers.environment
      "tags.datadoghq.com/service" = "istio-test"
      "tags.datadoghq.com/version" = var.istio_test_version
    }

    name      = "istio-test"
    namespace = "istio-test"
  }

  spec {
    replicas = var.istio_test_replicas

    selector {
      match_labels = {
        "app" = "istio-test"
      }
    }

    template {
      metadata {
        annotations = {
          "apm.datadoghq.com/env" = jsonencode({
            "DD_ENV"     = module.helpers.environment
            "DD_SERVICE" = "istio-test"
            "DD_VERSION" = var.istio_test_version
          })
        }

        labels = {
          # Enable Admission Controller to mutate new pods part of this deployment
          "admission.datadoghq.com/enabled" = "true"
          "app"                             = "istio-test"
          "tags.datadoghq.com/env"          = module.helpers.environment
          "tags.datadoghq.com/service"      = "istio-test"
          "tags.datadoghq.com/version"      = var.istio_test_version
        }
      }

      spec {
        container {
          env {
            name  = "DD_APPSEC_ENABLED"
            value = "true"
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
          env {
            name = "DD_VERSION"
            value_from {
              field_ref {
                field_path = "metadata.labels['tags.datadoghq.com/version']"
              }
            }
          }

          image             = "${local.registry}/istio-test:${var.istio_test_version}"
          image_pull_policy = "Always"

          liveness_probe {
            failure_threshold = 5

            http_get {
              path = "/istio-test/health"
              port = "8080"
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          name = "istio-test"

          port {
            container_port = 8080
          }

          readiness_probe {
            failure_threshold = 5

            http_get {
              path = "/istio-test/health"
              port = "8080"
            }

            initial_delay_seconds = 10
            period_seconds        = 10
            timeout_seconds       = 5
          }

          resources {
            limits = {
              cpu    = "20m"
              memory = "64Mi"
            }

            requests = {
              cpu    = "10m"
              memory = "32Mi"
            }
          }
        }

        topology_spread_constraint {
          label_selector {
            match_labels = {
              "app" = "istio-test"
            }
          }

          max_skew           = 1
          topology_key       = "kubernetes.io/zone"
          when_unsatisfiable = "ScheduleAnyway"
        }
      }
    }
  }
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "istio_test" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"

    metadata = {
      name      = "istio-test"
      namespace = "istio-test"
    }

    spec = {
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                namespaces = ["istio-ingress"]
                # principals = ["cluster.local/ns/istio-ingress/sa/gateway"]
              }
            }
          ]

          to = [
            {
              operation = {
                methods = ["GET"]

                # The authorization policy below uses the ALLOW-with-positive-matching pattern to allow requests to specific paths.

                paths = [
                  "/istio-test/health",
                  "/istio-test/metadata/cluster-location",
                  "/istio-test/metadata/cluster-name",
                  "/istio-test/metadata/instance-zone"
                ]
              }
            }
          ]
        }
      ]

      selector = {
        matchLabels = {
          app = "istio-test"
        }
      }
    }
  }
}

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "istio_test" {
  metadata {
    name      = "istio-test"
    namespace = "istio-test"
  }

  spec {
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    selector = {
      app = "istio-test"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_service_v1" "istio_test_regional" {
  metadata {
    name      = "istio-test-${module.helpers.region}-${module.helpers.zone}"
    namespace = "istio-test"
  }

  spec {
    port {
      name        = "http"
      port        = 8080
      target_port = 8080
    }

    selector = {
      app = "istio-test"
    }

    type = "ClusterIP"
  }
}
