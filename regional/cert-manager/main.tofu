# Kubernetes cert-manager Module (osinfra.io)
# https://github.com/osinfra-io/pt-arche-kubernetes-cert-manager

module "kubernetes_cert_manager" {
  source = "github.com/osinfra-io/pt-arche-kubernetes-cert-manager//regional?ref=c391006f8df18d6e4e2dc24499062f510619b07e" # TEMP: pre-release pin to osinfra-io/pt-arche-kubernetes-cert-manager#79 (istio-csr-ambient-ztunnel-trust); re-pin to tagged release once merged

  for_each = local.gke_clusters

  providers = {
    helm = helm.by_cluster[each.key]
  }

}
