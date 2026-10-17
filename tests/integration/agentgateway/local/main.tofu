# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "agentgateway_admin" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "agentgateway-admin"
      namespace = var.namespace
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
          filters = [
            {
              requestRedirect = {
                path = {
                  replaceFullPath = "/ui/"
                  type            = "ReplaceFullPath"
                }
                statusCode = 302
              }
              type = "RequestRedirect"
            }
          ]
          matches = [
            {
              path = {
                type  = "Exact"
                value = "/"
              }
            }
          ]
        },
        {
          backendRefs = [
            {
              name = "agentgateway-proxy-admin"
              port = 15000
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/ui"
              }
            },
            {
              path = {
                type  = "PathPrefix"
                value = "/api"
              }
            },
            {
              path = {
                type  = "Exact"
                value = "/config_dump"
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "agentgateway_admin_authorization" {
  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-admin"
      namespace = var.namespace
    }
    spec = {
      action = "DENY"
      rules = [
        {
          from = [
            {
              source = {
                notPrincipals = [var.istio_ingress_principal]
              }
            }
          ]
          to = [
            {
              operation = {
                ports = ["15000"]
              }
            }
          ]
        }
      ]
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = var.gateway_name
        }
      }
    }
  }
}

# Backend route rewriting keeps the existing diagnostic application shared by both gateways.
resource "kubernetes_manifest" "agentgateway_backend" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "agentgateway-backend"
      namespace = var.namespace
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
              name      = var.diagnostic_service
              namespace = var.diagnostic_namespace
              port      = var.diagnostic_service_port
            }
          ]
          filters = [
            {
              type = "URLRewrite"
              urlRewrite = {
                path = {
                  replacePrefixMatch = "/istio-test"
                  type               = "ReplacePrefixMatch"
                }
              }
            }
          ]
          matches = [
            {
              path = {
                type  = "PathPrefix"
                value = "/agentgateway-test"
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "agentgateway_ingress" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "agentgateway-ingress"
      namespace = var.namespace
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
                value = "/agentgateway-test"
              }
            }
          ]
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "agentgateway_reference_grant" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1beta1"
    kind       = "ReferenceGrant"
    metadata = {
      name      = "agentgateway"
      namespace = var.diagnostic_namespace
    }
    spec = {
      from = [
        {
          group     = "gateway.networking.k8s.io"
          kind      = "HTTPRoute"
          namespace = var.namespace
        }
      ]
      to = [
        {
          group = ""
          kind  = "Service"
          name  = var.diagnostic_service
        }
      ]
    }
  }
}

resource "kubernetes_manifest" "authentik_outpost" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "authentik-outpost-agentgateway"
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

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "agentgateway_admin" {
  metadata {
    name      = "agentgateway-proxy-admin"
    namespace = var.namespace
  }

  spec {
    port {
      name        = "http-admin"
      port        = 15000
      target_port = 15000
    }

    selector = {
      "gateway.networking.k8s.io/gateway-name" = var.gateway_name
    }
  }
}
