# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  state_bucket = "${module.core_helpers.repository}-state-${module.core_helpers.env}"
}
