# Kubernetes agentgateway Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-agentgateway

module "kubernetes_agentgateway" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-agentgateway//regional?ref=0304a4eb6038e8e7b47c504beb8dc5df0ca72f91" # v0.2.0

  for_each = local.agentgateway_clusters

  providers = {
    helm       = helm.by_cluster
    kubernetes = kubernetes.by_cluster
  }

  labels    = module.core_helpers.labels
  namespace = local.namespace
}
