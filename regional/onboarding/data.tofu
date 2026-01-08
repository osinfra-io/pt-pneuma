# Data Sources
# https://opentofu.org/docs/language/data-sources

# Google Client Config Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = module.helpers.zone
  name     = "cluster-${module.helpers.env}"
  project  = data.google_project.this.project_id
}

# Google Project Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/project

data "google_project" "this" {
  project_id = data.google_projects.this.projects[0].project_id
}

# Google Projects Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/projects

data "google_projects" "this" {
  filter = "parent.id:${module.helpers.environment_folder_id} labels.type=k8s labels.env=${module.helpers.env}"
}

# Terraform Remote State Data Source - Main
# https://opentofu.org/docs/language/state/remote-state-data

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket             = var.state_bucket
    kms_encryption_key = var.state_kms_encryption_key
  }

  workspace = "main-${module.helpers.environment}"
}
