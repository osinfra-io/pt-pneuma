# Data Sources
# https://opentofu.org/docs/language/data-sources

# Data Source: Google Projects
# Find the Kubernetes project created by pt-corpus for this team using a filter
# Project naming pattern: {team_key}-k8s-{random_suffix}-{env}

data "google_projects" "kubernetes" {
  filter = "labels.repository:${module.helpers.repository} labels.env:${module.helpers.env} name:*k8s* lifecycleState:ACTIVE"
}

# Data Source: Google Project
# Reference the single Kubernetes project from the filtered results

data "google_project" "kubernetes" {
  project_id = data.google_projects.kubernetes.projects[0].project_id
}
