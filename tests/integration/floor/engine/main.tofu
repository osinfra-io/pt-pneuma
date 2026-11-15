# Helm Release
# https://search.opentofu.org/provider/hashicorp/helm/latest/docs/resources/release

# The flux-system namespace is deliberately left unlabelled so the engine runs off the ambient mesh.
resource "helm_release" "flux_operator" {
  chart            = "flux-operator"
  create_namespace = true
  name             = "flux-operator"
  namespace        = "flux-system"
  repository       = "oci://ghcr.io/controlplaneio-fluxcd/charts"
  version          = var.flux_operator_chart_version
}

# The Branch Planner reads pull requests through source-controller, which the FluxInstance installs.
resource "helm_release" "tofu_controller" {
  depends_on = [
    kubernetes_config_map_v1.branch_planner,
    kubernetes_manifest.flux_instance
  ]

  chart      = "tofu-controller"
  name       = "tofu-controller"
  namespace  = "flux-system"
  repository = "https://flux-iac.github.io/tofu-controller/"

  values = [yamlencode(local.tofu_controller_values)]

  version = var.tofu_controller_chart_version
}

# Kubernetes Config Map
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/config_map_v1

resource "kubernetes_config_map_v1" "branch_planner" {
  depends_on = [
    helm_release.flux_operator
  ]

  metadata {
    name      = "branch-planner"
    namespace = "flux-system"
  }

  data = {
    resources  = local.branch_planner_resources
    secretName = "branch-planner-token"
  }
}

# Kubernetes Manifest Resource
# https://search.opentofu.org/provider/hashicorp/kubernetes/latest/docs/resources/manifest

resource "kubernetes_manifest" "flux_instance" {
  depends_on = [
    helm_release.flux_operator
  ]

  manifest = {
    apiVersion = "fluxcd.controlplane.io/v1"
    kind       = "FluxInstance"
    metadata = {
      name      = "flux"
      namespace = "flux-system"
    }
    spec = {
      cluster = {
        networkPolicy = false
      }
      components = [
        "source-controller",
        "kustomize-controller",
        "notification-controller"
      ]
      distribution = {
        registry = "ghcr.io/fluxcd"
        version  = var.flux_distribution_version
      }
    }
  }
}
