# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "datadog_api_key" {
  description = "Datadog API key"
  sensitive   = true
  type        = string
}

variable "datadog_app_key" {
  description = "Datadog APP key"
  sensitive   = true
  type        = string
}

variable "istio_test_replicas" {
  default     = 1
  description = "The number of replicas for the istio-test deployment"
  type        = number
}

variable "istio_test_version" {
  default     = "v0.3.8"
  description = "The version of the istio-test deployment"
  type        = string
}

# These three state_* variables are required for early variable evaluation for backend and provider configuration.
# They are defined in the GitHub Actions called workflows and should NOT be set in the OpenTofu configuration.

variable "state_bucket" {
  description = "The name of the GCS bucket to store state files"
  type        = string
}

variable "state_kms_encryption_key" {
  description = "The KMS encryption key for state and plan files"
  type        = string
}

variable "state_prefix" {
  description = "The prefix for state files in the GCS bucket"
  type        = string
}
