# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "brand_domain" {
  default     = "authentik.sb.osinfra.io"
  description = "Resolved hostname selecting the authentication brand"
  type        = string
}

variable "brand_title" {
  default     = "osinfra.io | Sandbox"
  description = "Browser title for the authentication brand"
  type        = string
}

variable "enabled" {
  default     = true
  description = "Create the custom brand and flow; identification settings remain available when disabled"
  type        = bool
}

variable "flow_title" {
  default     = "Welcome to osinfra.io sandbox!"
  description = "Name and heading of the custom authentication flow"
  type        = string
}

variable "policy_ids" {
  description = "Resolved built-in expression policy IDs keyed by authentication stage"
  type        = map(string)
}

variable "stage_ids" {
  description = "Resolved built-in stage IDs keyed by authentication stage"
  type        = map(string)
}
