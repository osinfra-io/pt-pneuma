# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "kubernetes_istio_gateway_cpu_limits" {
  default     = "100m"
  description = "The CPU limit for the Istio gateway"
  type        = string
}

variable "kubernetes_istio_gateway_cpu_requests" {
  default     = "25m"
  description = "The CPU request for the Istio gateway"
  type        = string
}

variable "kubernetes_istio_gateway_dns" {
  default     = {}
  description = "Map of attributes for the Istio gateway domain names, it is also used to create the managed certificate resource"

  type = map(object({
    managed_zone = string
    project      = string
  }))
}

variable "kubernetes_istio_gateway_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio gateway"
  type        = string
}

variable "kubernetes_istio_gateway_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio gateway"
  type        = string
}

variable "kubernetes_istio_pilot_cpu_limits" {
  default     = "25m"
  description = "The CPU limit for the Istio pilot"
  type        = string
}

variable "kubernetes_istio_pilot_cpu_requests" {
  default     = "10m"
  description = "The CPU request for the Istio pilot"
  type        = string
}

variable "kubernetes_istio_pilot_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio pilot"
  type        = string
}

variable "kubernetes_istio_pilot_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio pilot"
  type        = string
}

variable "kubernetes_istio_proxy_cpu_limits" {
  default     = "25m"
  description = "The CPU limit for the Istio proxy"
  type        = string
}

variable "kubernetes_istio_proxy_cpu_requests" {
  default     = "10m"
  description = "The CPU request for the Istio proxy"
  type        = string
}

variable "kubernetes_istio_proxy_memory_limits" {
  default     = "64Mi"
  description = "The memory limit for the Istio proxy"
  type        = string
}

variable "kubernetes_istio_proxy_memory_requests" {
  default     = "32Mi"
  description = "The memory request for the Istio proxy"
  type        = string
}

variable "remote_bucket" {
  description = "The remote bucket the `terraform_remote_state` data source retrieves the state from"
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
