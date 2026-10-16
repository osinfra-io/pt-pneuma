# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_token" {
  description = "Local Authentik bootstrap API token"
  sensitive   = true
  type        = string
}

variable "embedded_outpost_id" {
  description = "UUID of the built-in outpost discovered during bootstrap"
  type        = string
}

variable "google_oauth_client_id" {
  description = "Google web OAuth client with the registered localhost callback"
  sensitive   = true
  type        = string

  validation {
    condition     = length(var.google_oauth_client_id) > 0
    error_message = "Local integration requires Google OAuth credentials."
  }
}

variable "google_oauth_client_secret" {
  description = "Google OAuth secret supplied through the developer environment"
  sensitive   = true
  type        = string

  validation {
    condition     = length(var.google_oauth_client_secret) > 0
    error_message = "Local integration requires Google OAuth credentials."
  }

}

variable "revoke_application_access" {
  default     = false
  description = "Local-only revocation test: temporarily empty declared application memberships without changing Logos or diagnostic access."
  type        = bool
}

variable "teams" {
  description = "Actual Logos team declaration passed by the owning local setup script."
  type = map(object({
    authentik_groups = optional(map(object({
      description = string
      label       = string
      members = optional(object({
        non-production = optional(list(string), [])
        production     = optional(list(string), [])
        sandbox        = optional(list(string), [])
      }), {})
    })), {})
  }))
}
