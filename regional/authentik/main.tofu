# Kubernetes Authentik Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-authentik

module "kubernetes_authentik" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-authentik//regional?ref=2f13e837e5ad7b90317ad319f59e67dd8da86ba7" # create-authentik-module (branch ref pending release)

  depends_on = [
    kubernetes_namespace_v1.authentik,
    kubernetes_secret_v1.authentik,
  ]

  for_each = local.authentik_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  existing_secret        = kubernetes_secret_v1.authentik[each.key].metadata[0].name
  external_database_host = local.main.authentik_database_host
  external_database_name = local.main.authentik_database_name
  external_database_user = local.main.authentik_database_user
  namespace              = kubernetes_namespace_v1.authentik[each.key].metadata[0].name
}

# Kubernetes Namespace Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/namespace_v1

resource "kubernetes_namespace_v1" "authentik" {
  for_each = local.authentik_clusters
  provider = kubernetes.by_cluster[each.key]

  metadata {
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
