# Data Sources
# https://opentofu.org/docs/language/data-sources

# Google Client Config Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = local.zone
  name     = local.cluster_name
  project  = data.terraform_remote_state.regional.outputs.project_id
}

# Google Project Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project

data "google_project" "this" {
  project_id = data.terraform_remote_state.regional.outputs.project_id
}

# OpenTofu Remote State Data Source - Regional
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "regional" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = "pt-pneuma-regional"
  }

  workspace = "${local.region}-${local.zone}-${module.helpers.environment}"
}

# OpenTofu Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket             = var.remote_bucket
    kms_encryption_key = var.state_kms_encryption_key
    prefix             = "pt-pneuma"
  }

  workspace = "main-${module.helpers.environment}"
}
