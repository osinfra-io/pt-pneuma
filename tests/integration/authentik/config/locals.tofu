# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  application_groups = {
    for key, group in module.team_access.application_groups : key => merge(group, {
      members = var.revoke_application_access ? [] : group.members
    })
  }

  authentication_policy_ids = {
    for key, policy in data.authentik_policy_expression.authentication_stage_policies : key => policy.id
  }

  authentication_stage_ids = {
    for key, stage in data.authentik_stage.authentication_stages : key => stage.id
  }
}
