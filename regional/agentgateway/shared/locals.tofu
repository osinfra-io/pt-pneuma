# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  admin_closed_manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"
    metadata = {
      name      = "agentgateway-admin-not-published"
      namespace = local.namespace
    }
    spec = {
      action = "DENY"
      rules = [
        {
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
          "gateway.networking.k8s.io/gateway-name" = "agentgateway-proxy"
        }
      }
    }
  }

  gateway_clusters = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config
    if endswith(cluster_name, "-${local.zone}") && cluster_config.team_key == module.core_helpers.team
  }

  namespace = "${module.core_helpers.team}-agentgateway"

  regions = {
    for cluster_name in keys(var.clusters) :
    cluster_name => regex("(us-[a-z0-9]+)-[a-z]$", cluster_name)[0]
  }

  zone = "${module.core_helpers.region}-${module.core_helpers.zone}"
}
