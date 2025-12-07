# Data Sources
# https://opentofu.org/docs/language/data-sources

# Data Source: Google Projects (Kubernetes)
# Find the Kubernetes project created by pt-corpus for this team using a filter
# Project naming pattern: {team_key}-k8s-{random_suffix}-{env}
# Uses parent.id to scope to team's environment folder for reliable discovery
# Note: Projects are created by pt-corpus, so labels.repository will be "pt-corpus", not the team name
# The labels.description:k8s filter distinguishes Kubernetes projects from other pt-corpus projects

data "google_projects" "kubernetes" {
  filter = "parent.id:${module.helpers.environment_folder_id} labels.repository:pt-corpus labels.description:k8s lifecycleState:ACTIVE"
}

# Data Source: Google Project (Kubernetes)
# Reference the single Kubernetes project from the filtered results

data "google_project" "kubernetes" {
  count = length(data.google_projects.kubernetes.projects) > 0 ? 1 : 0

  project_id = data.google_projects.kubernetes.projects[0].project_id
}

# Data Source: Google Projects (Shared VPC Host)
# Find the pt-corpus shared VPC host project for this environment
# Project naming pattern: pt-corpus-{description}-{random_suffix}-{env}
# Uses parent.id to scope to pt-corpus environment folder for reliable discovery
# Excludes k8s projects by filtering out labels.description:k8s

data "google_projects" "shared_vpc_host" {
  filter = "parent.id:${module.helpers.teams["pt-corpus"].environments[local.environment_key]} labels.repository:pt-corpus -labels.description:k8s lifecycleState:ACTIVE"
}

# Data Source: Google Project (Shared VPC Host)
# Reference the single shared VPC host project from the filtered results

data "google_project" "shared_vpc_host" {
  count = length(data.google_projects.shared_vpc_host.projects) > 0 ? 1 : 0

  project_id = data.google_projects.shared_vpc_host.projects[0].project_id
}
