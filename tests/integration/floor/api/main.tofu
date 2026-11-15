# Kubernetes Cluster Role Binding
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/cluster_role_binding_v1

resource "kubernetes_cluster_role_binding_v1" "floor_api" {
  metadata {
    name = "floor-api"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.floor_api.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.floor_api.metadata[0].name
    namespace = var.namespace
  }
}

# Kubernetes Cluster Role
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/cluster_role_v1

resource "kubernetes_cluster_role_v1" "floor_api" {
  metadata {
    name = "floor-api"
  }

  # Approvals are recorded as Events on the Terraform object they approve.
  rule {
    api_groups = [""]
    resources  = ["events"]
    verbs      = ["create", "patch"]
  }

  rule {
    api_groups = ["infra.contrib.fluxcd.io"]
    resources  = ["terraforms"]
    verbs      = ["get", "list", "patch", "watch"]
  }

  rule {
    api_groups = ["infra.contrib.fluxcd.io"]
    resources  = ["terraforms/status"]
    verbs      = ["get"]
  }

  # The sandbox repoints the fixture GitRepository at a pull request head.
  rule {
    api_groups = ["source.toolkit.fluxcd.io"]
    resources  = ["gitrepositories"]
    verbs      = ["get", "list", "patch", "watch"]
  }
}

# Kubernetes Deployment
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/deployment_v1

resource "kubernetes_deployment_v1" "floor_api" {
  metadata {
    name      = "floor-api"
    namespace = var.namespace
  }

  spec {
    replicas = 1

    selector {
      match_labels = local.selector_labels
    }

    template {
      metadata {
        annotations = local.pod_annotations
        labels      = local.pod_labels
      }

      spec {
        container {
          image             = var.image
          image_pull_policy = "Never"
          name              = "floor-api"

          env {
            name  = "FLOOR_APPROVER_GROUP"
            value = var.approver_group
          }

          env {
            name  = "FLOOR_GIT_REPOSITORY"
            value = var.git_repository
          }

          env {
            name  = "FLOOR_GITHUB_REPO"
            value = var.github_repository
          }

          env {
            name  = "FLOOR_NAMESPACE"
            value = var.fixture_namespace
          }

          env {
            name = "GITHUB_TOKEN"

            value_from {
              secret_key_ref {
                key  = "token"
                name = var.github_token_secret
              }
            }
          }

          port {
            container_port = var.service_port
            name           = "http"
          }

          readiness_probe {
            http_get {
              path = "/healthz"
              port = var.service_port
            }
          }
        }

        service_account_name = kubernetes_service_account_v1.floor_api.metadata[0].name
      }
    }
  }
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "authentik_outpost" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "authentik-outpost-floor"
      namespace = var.authentik_namespace
    }
    spec = {
      hostnames = [var.hostname]
      parentRefs = [
        {
          name      = var.istio_gateway_name
          namespace = var.istio_gateway_namespace
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              name = var.authentik_service
              port = var.authentik_http_port
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/outpost.goauthentik.io"
              }
            }
          ]
        }
      ]
    }
  }
}

# Only the agentgateway proxy may reach floor-api, which trusts the identity headers it forwards.
resource "kubernetes_manifest" "floor_api_authorization" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "floor-api"
      namespace = var.namespace
    }
    spec = {
      action = "DENY"
      rules = [
        {
          from = [
            {
              source = {
                notPrincipals = [var.gateway_principal]
              }
            }
          ]
          to = [
            {
              operation = {
                ports = [tostring(var.service_port)]
              }
            }
          ]
        }
      ]
      selector = {
        matchLabels = local.selector_labels
      }
    }
  }
}

# agentgateway proxies the MCP endpoint, so the backend route is parented by its Gateway.
resource "kubernetes_manifest" "floor_backend" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "floor-backend"
      namespace = var.gateway_namespace
    }
    spec = {
      hostnames = [var.hostname]
      parentRefs = [
        {
          name = var.gateway_name
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              kind      = "Service"
              name      = "floor-api"
              namespace = var.namespace
              port      = var.service_port
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
        }
      ]
    }
  }
}

# Approving a pull request plan blocks while the planner re-plans at the head, so the
# route timeout is set above floor-api's revision timeout.
resource "kubernetes_manifest" "floor_ingress" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "floor-ingress"
      namespace = var.gateway_namespace
    }
    spec = {
      hostnames = [var.hostname]
      parentRefs = [
        {
          name      = var.istio_gateway_name
          namespace = var.istio_gateway_namespace
        }
      ]
      rules = [
        {
          backendRefs = [
            {
              name = var.gateway_name
              port = 80
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/"
              }
            }
          ]
          timeouts = {
            request = var.request_timeout
          }
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "floor_reference_grant" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "floor-api"
      namespace = var.namespace
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = var.gateway_namespace
        }
      ]
      to = [
        {
          group = ""
          kind  = "Service"
          name  = "floor-api"
        }
      ]
    }
  }
}

# Kubernetes Service Account
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_account_v1

resource "kubernetes_service_account_v1" "floor_api" {
  metadata {
    name      = "floor-api"
    namespace = var.namespace
  }
}

# Kubernetes Service
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "floor_api" {
  metadata {
    name      = "floor-api"
    namespace = var.namespace
  }

  spec {
    port {
      name        = "http"
      port        = var.service_port
      target_port = var.service_port
    }

    selector = local.selector_labels
  }
}
