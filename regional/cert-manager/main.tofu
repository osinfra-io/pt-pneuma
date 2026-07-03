# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=bb00d8bd52c54cbdde002d88808df07b035e6c1c" # v0.3.0

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

  artifact_registry = "us-docker.pkg.dev/pt-corpus-tf16-prod/${module.core_helpers.team}-virtual"
}
