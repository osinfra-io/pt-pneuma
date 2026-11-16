# Local Values
# https://opentofu.org/docs/language/values/locals

# The selector is shared by the Deployment and the Service, and the pod template
# carries the Datadog unified service tagging labels alongside it.

locals {
  additional_namespaces = join(",", sort(tolist(var.additional_namespaces)))

  # Rolling the pods is the only way a changed token reaches the running process.
  pod_annotations = {
    "checksum/github-token" = var.github_token_checksum
  }

  pod_labels = merge(local.selector_labels, {
    "tags.datadoghq.com/env"     = "sandbox"
    "tags.datadoghq.com/service" = "floor-api"
    "tags.datadoghq.com/version" = var.version_label
  })

  selector_labels = {
    "app.kubernetes.io/name" = "floor-api"
  }
}
