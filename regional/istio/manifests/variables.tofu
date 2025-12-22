# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "kubernetes_istio_common_istio_test_virtual_services" {
  description = "The map of Istio VirtualServices to create for Istio testing, that are common among all regions"
  type = map(object({
    destination_host = string
    host             = string
  }))
}

variable "kubernetes_istio_common_virtual_services" {
  default     = {}
  description = "The map of Istio VirtualServices to create, that are common among all regions"
  type = map(object({
    destination_host = string
    destination_port = optional(number, 8080)
    host             = string
  }))
}

variable "kubernetes_istio_failover_from_region" {
  default     = ""
  description = "The region to fail over from"
  type        = string
}

variable "kubernetes_istio_failover_to_region" {
  default     = ""
  description = "The region to fail over to"
  type        = string
}

variable "kubernetes_istio_test_virtual_services" {
  description = "The map of Istio VirtualServices to create for Istio testing"
  type = map(object({
    destination_host = string
    host             = string
  }))
}

variable "kubernetes_istio_virtual_services" {
  default     = {}
  description = "The map of Istio VirtualServices to create, that are unique to a region"
  type = map(object({
    destination_host = string
    destination_port = optional(number, 8080)
    host             = string
  }))
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
