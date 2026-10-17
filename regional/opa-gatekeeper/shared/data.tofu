# Google Client Config Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = module.core_helpers.region
  name     = "${module.core_helpers.team}-${module.core_helpers.region}-${module.core_helpers.zone}"
  project  = data.terraform_remote_state.main.outputs.project_id
}

# OpenTofu Remote State Datasource
# https://opentofu.org/docs/language/state/remote-state-data/

data "terraform_remote_state" "main" {
  backend = "gcs"

  config = {
    bucket = local.state_bucket
    prefix = module.core_helpers.repository
  }

  workspace = "main-${module.core_helpers.environment}"
}
