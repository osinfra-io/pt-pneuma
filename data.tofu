# Data Sources
# https://opentofu.org/docs/language/data-sources

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

# Data Source: Google Projects (Shared VPC Host)
# Find the pt-corpus shared VPC host project for this environment
# Project naming pattern: pt-corpus-{random_suffix}-{env}
# Uses parent.id to scope to pt-corpus environment folder for reliable discovery

data "google_projects" "shared_vpc_host" {
  # Use supported fields: parent.id, labels, lifecycleState
  # Finds the pt-corpus main project using labels.team:pt-corpus (k8s projects have different team labels)
  # Strip 'folders/' prefix from folder ID since API expects just the numeric ID
  filter = "parent.id:${replace(module.helpers.teams["pt-corpus"].environments[local.environment_key], "folders/", "")} labels.repository:pt-corpus labels.team:pt-corpus lifecycleState:ACTIVE"
}

# Data Source: Google Project (Shared VPC Host)
# Reference the single shared VPC host project from the filtered results

data "google_project" "shared_vpc_host" {
  lifecycle {
    enabled = length(data.google_projects.shared_vpc_host.projects) > 0
  }

  project_id = data.google_projects.shared_vpc_host.projects[0].project_id
}
