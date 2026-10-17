# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "active_zones" {
  description = "The GKE zones active in this environment"
  type        = set(string)
}
