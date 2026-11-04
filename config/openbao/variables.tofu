# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "openbao_address" {
  description = "HTTPS address of the supported OpenBao instance"
  type        = string

  validation {
    condition     = can(regex("^https://[^/]+$", var.openbao_address))
    error_message = "The OpenBao address must be an HTTPS origin without a path."
  }
}
