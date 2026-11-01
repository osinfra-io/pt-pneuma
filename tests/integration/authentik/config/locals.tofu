# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  authentik_group_defaults = {
    openbao-secret-admins = {
      description = "Manage secrets and versions within the %s team prefix"
      label       = "OpenBao Secret Admins"
    }
    openbao-secret-readers = {
      description = "Read and list secrets within the %s team prefix"
      label       = "OpenBao Secret Readers"
    }
    openbao-secret-writers = {
      description = "Create and update secrets within the %s team prefix"
      label       = "OpenBao Secret Writers"
    }
  }

  application_groups = {
    for key, group in module.team_access.application_groups : key => merge(group, {
      members = var.revoke_application_access ? [] : group.members
    })
  }

  team_access_teams = {
    for team_key, team in var.teams : team_key => {
      authentik_groups = {
        for key, group in team.authentik_groups : key => {
          description = group.description != null ? group.description : try(format(local.authentik_group_defaults[key].description, team_key), null)
          label       = group.label != null ? group.label : try(local.authentik_group_defaults[key].label, null)
          members     = group.members
          name        = group.name != null ? group.name : "${team_key}: ${group.label != null ? group.label : try(local.authentik_group_defaults[key].label, key)}"
        }
      }
    }
  }

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.authentication_stages : key => stage.id
  }
}
