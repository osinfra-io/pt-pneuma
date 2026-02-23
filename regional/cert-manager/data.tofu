# Data Sources
# https://opentofu.org/docs/language/data-sources

# Google Client Config Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config

data "google_client_config" "this" {}

# Google Container Cluster Data Source
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/container_cluster

data "google_container_cluster" "this" {
  location = module.helpers.region
  name     = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
  project  = data.google_project.kubernetes.project_id
}

# Data Source: Google Projects (Kubernetes)
# Find the Kubernetes project created by pt-corpus for this team using a filter
# Project naming pattern: {team_key}-k8s-{random_suffix}-{env}
# Uses parent.id to scope to team's environment folder for reliable discovery
# Note: Projects are created by pt-corpus, so labels.repository="pt-corpus" but labels.team identifies the owning team

data "google_projects" "kubernetes" {
  # Use supported fields: parent.id, labels, lifecycleState
  # Matches Kubernetes projects using labels.team to identify the owning team's k8s project
  # Strip 'folders/' prefix from folder ID since API expects just the numeric ID
  filter = "parent.id:${replace(module.helpers.environment_folder_id, "folders/", "")} labels.repository:pt-corpus labels.team:${module.helpers.team} lifecycleState:ACTIVE"
}

# Data Source: Google Project (Kubernetes)
# Reference the single Kubernetes project from the filtered results

data "google_project" "kubernetes" {
  lifecycle {
    enabled = length(data.google_projects.kubernetes.projects) > 0
  }

  project_id = data.google_projects.kubernetes.projects[0].project_id
}
