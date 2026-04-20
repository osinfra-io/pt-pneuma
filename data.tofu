# Data Source: Google Project (Platform-Managed)
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/project
# Reference the single platform-managed project from the filtered results

data "google_project" "platform_managed" {
  project_id = data.google_projects.platform_managed.projects[0].project_id
}

data "google_project" "shared_vpc_host" {
  lifecycle {
    enabled = length(data.google_projects.shared_vpc_host.projects) > 0
  }

  project_id = data.google_projects.shared_vpc_host.projects[0].project_id
}

# Data Source: Google Projects
# https://search.opentofu.org/provider/hashicorp/google/latest/docs/data-sources/projects
# Discover GCP projects using label filters scoped to environment folders
# Projects are created by pt-corpus: labels.repository=pt-corpus, labels.team identifies the owning team

data "google_projects" "platform_managed" {
  # Use supported fields: parent.id, labels, lifecycleState
  # Matches platform-managed projects using labels.team to identify the owning team's project
  # Strip 'folders/' prefix from folder ID since API expects just the numeric ID
  filter = "parent.id:${replace(module.core_helpers.environment_folder_id, "folders/", "")} labels.repository:pt-corpus labels.team:${module.core_helpers.team} labels.project-type:platform-managed lifecycleState:ACTIVE"
}

data "google_projects" "shared_vpc_host" {
  # Use supported fields: parent.id, labels, lifecycleState
  # Finds the pt-corpus main project using labels.team:pt-corpus (k8s projects have different team labels)
  # Strip 'folders/' prefix from folder ID since API expects just the numeric ID
  filter = "parent.id:${replace(module.core_helpers.teams["pt-corpus"].environments[local.environment_key], "folders/", "")} labels.repository:pt-corpus labels.team:pt-corpus lifecycleState:ACTIVE"
}

data "google_projects" "team_platform_managed" {
  for_each = local.teams_with_clusters

  # Use supported fields: parent.id, labels, lifecycleState
  # Matches each team's platform-managed project using labels.team scoped to that team's environment folder
  # Strip 'folders/' prefix from folder ID since API expects just the numeric ID
  filter = "parent.id:${replace(module.core_helpers.teams[each.key].environments[local.environment_key], "folders/", "")} labels.repository:pt-corpus labels.team:${each.key} labels.project-type:platform-managed lifecycleState:ACTIVE"
}
