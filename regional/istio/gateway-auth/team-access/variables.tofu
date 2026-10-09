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
        group.label != null || group.name != null
      ]
    ]))
    error_message = "Application groups require a Logos label or resolved team-qualified name."
  }
}
