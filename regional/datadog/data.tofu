# Google Client Config Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/container_cluster
# Looks up every cluster so the Helm provider for_each remains a superset of the
# module for_each (required for safe removal of a cluster in a future apply)

data "google_container_cluster" "this" {
  for_each = var.clusters

  location = local.regions[each.key]
  name     = each.key
  project  = each.value.project_id
}

# OpenTofu Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}
