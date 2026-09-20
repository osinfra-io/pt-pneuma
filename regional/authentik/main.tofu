# Kubernetes Authentik Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "kubernetes_authentik" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional?ref=76e4fba9538c0c1da9f9615e4408abcf328259a8" # v0.1.5

  depends_on = [
    kubernetes_secret_v1.authentik,
  ]

  for_each = local.authentik_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  cloud_sql_connection_name        = local.main.authentik_cloud_sql_connection_name
  existing_secret                  = kubernetes_secret_v1.authentik[each.key].metadata[0].name
  external_database_name           = local.main.authentik_database_name
  external_database_user           = local.main.authentik_database_user
  google_service_account_email     = local.main.authentik_cloud_sql_service_account_email
  namespace                        = local.authentik_namespace
  server_replicas                  = local.authentik_server_replicas
  server_resources_requests_cpu    = local.authentik_server_resources_requests_cpu
  server_resources_requests_memory = local.authentik_server_resources_requests_memory
  worker_replicas                  = local.authentik_worker_replicas
  worker_resources_requests_cpu    = local.authentik_worker_resources_requests_cpu
  worker_resources_requests_memory = local.authentik_worker_resources_requests_memory
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

# Under the mesh's default-deny AuthorizationPolicy, an injected Authentik would be unreachable.
# Allow the ingress gateway (istio-ingress) to reach the Authentik server for both the ext_authz
# forward-auth calls and the UI/OIDC traffic routed through the shared gateway. No path/method
# restriction: as the identity provider, every Authentik endpoint must be reachable.
resource "kubernetes_manifest" "authentik_allow_gateway" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  manifest = {
    apiVersion = "security.istio.io/v1"
    kind       = "AuthorizationPolicy"

    metadata = {
      name      = "authentik-allow-gateway"
      namespace = local.authentik_namespace
    }

    spec = {
      action = "ALLOW"
      rules = [
        {
          from = [
            {
              source = {
                namespaces = ["istio-ingress"]
              }
            }
          ]
        }
      ]

      selector = {
        matchLabels = {
          "app.kubernetes.io/component" = "server"
          "app.kubernetes.io/instance"  = "authentik"
          "app.kubernetes.io/name"      = "authentik"
        }
      }
    }
  }
}

# Kubernetes Secret Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/secret_v1

resource "kubernetes_secret_v1" "authentik" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  data = local.main.authentik_secret_env

  metadata {
    name      = local.authentik_secret_name
    namespace = local.authentik_namespace
  }

  type = "Opaque"
}
