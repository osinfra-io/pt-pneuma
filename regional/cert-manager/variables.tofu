# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone for the Kubernetes and Helm providers."

  type = map(object({
    project_id = string
    team_key   = string
  }))
}

variable "kubernetes_cert_manager_cainjector_replicas" {
  default     = 1
  description = "The number of cert-manager cainjector replicas to run"
  type        = number
}

variable "kubernetes_cert_manager_cainjector_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the cainjector resources"
  type        = string
}

variable "kubernetes_cert_manager_cainjector_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the cainjector resources"
  type        = string
}

variable "kubernetes_cert_manager_cainjector_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the cainjector resources"
  type        = string
}

variable "kubernetes_cert_manager_cainjector_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the cainjector resources"
  type        = string
}

variable "kubernetes_cert_manager_replicas" {
  default     = 1
  description = "The number of cert-manager controller replicas to run"
  type        = number
}

variable "kubernetes_cert_manager_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the resources"
  type        = string
}

variable "kubernetes_cert_manager_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the resources"
  type        = string
}

variable "kubernetes_cert_manager_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the resources"
  type        = string
}

variable "kubernetes_cert_manager_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the resources"
  type        = string
}

variable "kubernetes_cert_manager_startupapicheck_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the startupapicheck resources"
  type        = string
}

variable "kubernetes_cert_manager_startupapicheck_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the startupapicheck resources"
  type        = string
}

variable "kubernetes_cert_manager_startupapicheck_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the startupapicheck resources"
  type        = string
}

variable "kubernetes_cert_manager_startupapicheck_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the startupapicheck resources"
  type        = string
}

variable "kubernetes_cert_manager_webhook_replicas" {
  default     = 1
  description = "The number of cert-manager webhook replicas to run"
  type        = number
}

variable "kubernetes_cert_manager_webhook_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the webhook resources"
  type        = string
}

variable "kubernetes_cert_manager_webhook_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the webhook resources"
  type        = string
}

variable "kubernetes_cert_manager_webhook_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the webhook resources"
  type        = string
}

variable "kubernetes_cert_manager_webhook_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the webhook resources"
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
