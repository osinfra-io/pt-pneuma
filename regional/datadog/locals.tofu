# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name   = "${module.core_helpers.team}-${module.core_helpers.region}-${module.core_helpers.zone}"
  enable_datadog = module.core_helpers.teams["pt-pneuma"].enable_kubernetes_datadog
}
