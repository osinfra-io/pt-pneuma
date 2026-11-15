# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "approver_group" {
  description = "Authentik group whose members may approve plans through floor-api"
  type        = string
  default     = "pt-techne: floor Approvers"
}

variable "authentik_token" {
  description = "Authentik bootstrap token used to manage the verification identity"
  type        = string
  sensitive   = true
}

variable "authentik_url" {
  description = "Authentik admin API URL, reached over a loopback forward because the provider cannot resolve .localhost"
  type        = string
}

variable "token_file" {
  description = "Path the generated app password for the verification user is written to"
  type        = string
}

variable "username" {
  description = "Username of the local verification identity"
  type        = string
  default     = "floor-verify"
}

variable "visitor_token_file" {
  description = "Path the generated app password for the visitor identity is written to"
  type        = string
}

variable "visitor_username" {
  description = "Username of the local identity that authenticates without the approver group"
  type        = string
  default     = "floor-visitor"
}
