# Kubernetes Authentik Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "kubernetes_authentik" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional?ref=88b4ba2fea6dc0623e984b8729857470f2bf8134" # v0.1.0

  depends_on = [
    kubernetes_namespace_v1.authentik,
    kubernetes_secret_v1.authentik,
  ]

  for_each = local.authentik_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  cloud_sql_connection_name    = local.main.authentik_cloud_sql_connection_name
  existing_secret              = kubernetes_secret_v1.authentik[each.key].metadata[0].name
  external_database_name       = local.main.authentik_database_name
  external_database_user       = local.main.authentik_database_user
  google_service_account_email = local.main.authentik_cloud_sql_service_account_email
  namespace                    = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
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
      namespace = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
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

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "authentik" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  metadata {
    labels = {
      "istio-injection" = "enabled"
    }

    name = local.authentik_namespace
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
    namespace = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
  }

  type = "Opaque"
}
