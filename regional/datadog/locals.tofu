# Local Values
# https://opentofu.org/docs/language/values/locals

locals {
  cluster_name   = "${module.helpers.team}-${module.helpers.region}-${module.helpers.zone}"
  enable_datadog = module.helpers.teams["pt-pneuma"].enable_kubernetes_datadog
}
