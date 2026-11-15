# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "fixture_namespace" {
  description = "Namespace holding the floor fixture Terraform objects and the runner environment secret"
  type        = string
  default     = "pt-techne-floor-fixture"
}

variable "flux_distribution_version" {
  description = "Flux distribution version range installed by the Flux Operator"
  type        = string
  default     = "2.10.x"
}

variable "flux_operator_chart_version" {
  description = "Flux Operator Helm chart version"
  type        = string
  default     = "0.62.1"
}

variable "tofu_controller_chart_version" {
  description = "tofu-controller Helm chart version"
  type        = string
  default     = "0.16.6"
}

variable "tofu_controller_runner_image_tag" {
  description = "tofu-controller runner image tag, pinned to the chart default rather than tracking the chart appVersion"
  type        = string
  default     = "v0.16.6"
}
