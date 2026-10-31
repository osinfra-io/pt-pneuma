# Mocked CRD lifecycle configuration
# https://opentofu.org/docs/cli/commands/test/

mock_provider "helm" {}
mock_provider "kubernetes" {}

run "cloud_crd_lifecycle_unchanged" {
  command = plan

  module {
    source = "../../../../../../arche/pt-arche-kubernetes-agentgateway/regional"
  }

  variables {
    namespace = "caller-owned-agentgateway"
  }

  assert {
    condition     = helm_release.agentgateway_crds.postrender == null
    error_message = "The default cloud deployment must not acquire a local-only post-renderer."
  }

  assert {
    condition     = helm_release.agentgateway.namespace == "caller-owned-agentgateway" && helm_release.agentgateway_crds.namespace == "caller-owned-agentgateway" && kubernetes_manifest.agentgateway.manifest.metadata.namespace == "caller-owned-agentgateway"
    error_message = "All deployment resources must use the namespace supplied by the caller."
  }
}

run "local_crd_retention" {
  command = plan

  assert {
    condition     = local.crds_postrender.binary_path == "bash" && endswith(local.crds_postrender.args[0], "/tests/integration/agentgateway/retain-crds.sh")
    error_message = "The local CRD chart must retain every CRD without invoking a live Kubernetes patch."
  }
}
