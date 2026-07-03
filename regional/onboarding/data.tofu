# Google Client Config Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/container_cluster
# Looks up every cluster so the Kubernetes provider for_each remains a superset of the
# module for_each (required for safe removal of a cluster in a future apply)

data "google_container_cluster" "this" {
  for_each = var.clusters

  location = local.regions[each.key]
  name     = each.key
  project  = each.value.project_id
}

# Google Service Account Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/service_account
# Each team's GitHub Actions service account, created in pt-corpus, bound as namespace-admin

data "google_service_account" "github" {
  for_each = local.teams_in_zone

  account_id = "${each.value}-github"
  project    = local.main.shared_vpc_host_project_id
}

# Terraform Remote State Data Source - Main
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
