# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

# The route is exposed only through the local Istio ingress Gateway; OpenBao authenticates every
# API request itself.
resource "kubernetes_manifest" "openbao" {
  manifest = {
    apiVersion = "gateway.networking.k8s.io/v1"
    kind       = "HTTPRoute"
    metadata = {
      name      = "openbao"
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
              name = var.service_name
              port = var.service_port
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
