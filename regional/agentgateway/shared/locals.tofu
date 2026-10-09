# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  admin_allow_manifest = merge(local.admin_authorization_manifest, {
    metadata = {
      name      = "agentgateway-admin-ingress"
      namespace = local.namespace
    }
    spec = merge(local.admin_authorization_manifest.spec, {
      action = "ALLOW"
      rules = [{
        from = [{
          source = {
            principals = ["cluster.local/ns/istio-ingress/sa/gateway-istio"]
          }
        }]
        to = [{
          operation = {
            ports = ["15000"]
          }
        }]
      }]
    })
  })

  admin_authorization_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-admin"
      namespace = local.namespace
    }
    spec = {
      action = "DENY"
      rules = [{
        from = [{
          source = {
            notPrincipals = ["cluster.local/ns/istio-ingress/sa/gateway-istio"]
          }
        }]
        to = [{
          operation = {
            ports = ["15000"]
          }
        }]
      }]
      selector = {
        matchLabels = {
          "gateway.networking.k8s.io/gateway-name" = "agentgateway-proxy"
        }
      }
    }
  }

  agentgateway_clusters = {
    for name, cluster in var.clusters : name => cluster
    if endswith(name, "-${local.zone}") && cluster.team_key == module.core_helpers.team && module.core_helpers.environment == "sandbox"
  }

  namespace = "${module.core_helpers.team}-agentgateway"

  proxy_env = {
    ADMIN_ADDR = "0.0.0.0:15000"
  }

  regions = {
    for name in keys(var.clusters) : name => regex("(us-[a-z0-9]+)-[a-z]$", name)[0]
  }

  zone = try(regex("^(us-[a-z0-9]+-[a-z])", terraform.workspace)[0], "")
}
