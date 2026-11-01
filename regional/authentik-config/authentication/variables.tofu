# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "brand_domain" {
  description = "Resolved hostname selecting the authentication brand"
  type        = string
}

variable "brand_title" {
  description = "Browser title for the authentication brand"
  type        = string
}

variable "flow_title" {
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
