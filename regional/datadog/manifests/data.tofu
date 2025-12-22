# Google Client Config Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/client_config


data "google_client_config" "this" {
}

# Google Container Cluster Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = module.helpers.region
  name     = "pt-${module.helpers.region}-${module.helpers.zone}"
  project  = data.google_project.this.project_id
}

# Google Projects Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/projects

data "google_projects" "this" {
  filter = "name:pt-k8s-* labels.env:${module.helpers.environment}"
}

# Google Project Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/project

data "google_project" "this" {
  project_id = data.google_projects.this.projects.0.project_id
}
