# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  application_groups = merge({}, [
    for team_key, team in var.teams : {
      for key, group in team.authentik_groups : "${team_key}/${key}" => {
        description = group.description
        members     = group.members[var.environment]
        name        = group.name != null ? group.name : "${team_key}: ${group.label}"
      }
    }
  ]...)

  application_group_members = {
    for group in values(local.application_groups) : group.name => group.members
  }
}
