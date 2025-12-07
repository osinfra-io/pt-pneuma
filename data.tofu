# Data Sources
# https://opentofu.org/docs/language/data-sources

# Data Source: Google Projects (Kubernetes)
# Find the Kubernetes project created by pt-corpus for this team using a filter
# Project naming pattern: {team_key}-k8s-{random_suffix}-{env}

data "google_projects" "kubernetes" {
  filter = "labels.repository:${module.helpers.repository} labels.env:${module.helpers.env} name:*k8s* lifecycleState:ACTIVE"
}

# Data Source: Google Project (Kubernetes)
# Reference the single Kubernetes project from the filtered results

data "google_project" "kubernetes" {
  project_id = data.google_projects.kubernetes.projects[0].project_id
}

# Data Source: Google Projects (Shared VPC Host)
# Find the pt-corpus shared VPC host project for this environment
# Project naming pattern: pt-corpus-{description}-{random_suffix}-{env}

data "google_projects" "shared_vpc_host" {
  filter = "labels.repository:pt-corpus labels.team:pt-corpus labels.env:${module.helpers.env} lifecycleState:ACTIVE"
}

# Data Source: Google Project (Shared VPC Host)
# Reference the single shared VPC host project from the filtered results

data "google_project" "shared_vpc_host" {
  project_id = data.google_projects.shared_vpc_host.projects[0].project_id
}
