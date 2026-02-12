# Google Client Config Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = module.helpers.region
  name     = "pt-${module.helpers.region}-${module.helpers.zone}"
  project  = local.kubernetes_project
}

# Google Projects Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/projects

data "google_projects" "kubernetes" {
  filter = "labels.env=${module.helpers.env} labels.prefix=pt labels.service=k8s"
}

# Google Project Data Source
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/project

data "google_project" "kubernetes" {
  project_id = data.google_projects.kubernetes.projects[0].project_id
}
