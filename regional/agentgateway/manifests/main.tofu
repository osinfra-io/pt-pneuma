# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway_manifests" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional/manifests?ref=9a362bdc6430338286fa206f1ae7f3009b03bd09" # v0.1.0

  for_each = local.agentgateway_clusters

  providers = {
    kubernetes = kubernetes.by_cluster[each.key]
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
  proxy_env = local.proxy_env
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "agentgateway_admin_allow" {
  for_each = local.agentgateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = local.admin_allow_manifest
}

resource "kubernetes_manifest" "agentgateway_admin_authorization" {
  for_each = local.agentgateway_clusters

  provider = kubernetes.by_cluster[each.key]

  manifest = local.admin_authorization_manifest
}

# Kubernetes Service Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/service_v1

resource "kubernetes_service_v1" "agentgateway_admin" {
  depends_on = [
    kubernetes_manifest.agentgateway_admin_allow,
    kubernetes_manifest.agentgateway_admin_authorization,
  ]

  for_each = local.agentgateway_clusters

  provider = kubernetes.by_cluster[each.key]

  metadata {
    name      = "agentgateway-proxy-admin"
    namespace = local.namespace
  }

  spec {
    port {
      name        = "http-admin"
      port        = 15000
      target_port = 15000
    }

    selector = {
      "gateway.networking.k8s.io/gateway-name" = "agentgateway-proxy"
    }
    type = "ClusterIP"
  }
}
