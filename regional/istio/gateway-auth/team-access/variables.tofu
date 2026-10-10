# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "environment" {
  description = "Long environment name selecting explicit application membership lists."
  type        = string

  validation {
    condition     = contains(["non-production", "production", "sandbox"], var.environment)
    error_message = "Application access requires sandbox, non-production, or production."
  }
}

variable "teams" {
  description = "Logos team declarations or core-helper team outputs; unrelated fields are discarded."
  type = map(object({
    authentik_groups = optional(map(object({
      description = string
      label       = optional(string)
      name        = optional(string)
      members = optional(object({
        non-production = optional(list(string), [])
        production     = optional(list(string), [])
        sandbox        = optional(list(string), [])
      }), {})
    })), {})
  }))

  validation {
    condition = alltrue(flatten([
      for team_key, team in var.teams : [
        for group in values(team.authentik_groups) :
        group.name != null ? (
          startswith(group.name, "${team_key}: ") &&
          can(regex("^(pt|st|ct|et)-[a-z0-9-]+: [A-Za-z][A-Za-z0-9]*( [A-Za-z0-9]+)*$", group.name)) &&
          (group.label == null ? true : group.name == "${team_key}: ${group.label}")
          ) : (
          group.label != null && can(regex("^[A-Za-z][A-Za-z0-9]*( [A-Za-z0-9]+)*$", group.label))
        )
      ]
    ]))
    error_message = "Application groups require a valid Logos label or exact owning-team qualified name; when both are supplied they must agree."
  }

  validation {
    condition = alltrue(flatten([
      for team in values(var.teams) : [
        for group in values(team.authentik_groups) : [
          for members in [group.members.non-production, group.members.production, group.members.sandbox] :
          length(members) == length(distinct(members)) && alltrue([
            for email in members : can(regex("^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9-]+(\\.[a-z0-9-]+)+$", email))
          ])
        ]
      ]
    ]))
    error_message = "Application member lists must contain unique lowercase email addresses in every environment."
  }
}
