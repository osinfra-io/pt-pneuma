# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_server_replicas" {
  description = "The number of replicas for the Authentik server"
  type        = number
}

variable "authentik_server_resources_limits_memory" {
  default     = "1Gi"
  description = "The memory limit for the Authentik server"
  type        = string
}

variable "authentik_server_resources_requests_cpu" {
  description = "The Authentik server CPU resource request"
  type        = string
}

variable "authentik_server_resources_requests_memory" {
  description = "The Authentik server memory resource request"
  type        = string
}

variable "authentik_worker_replicas" {
  default     = 1
  description = "The number of Authentik worker replicas to run"
  type        = number
}

variable "authentik_worker_resources_limits_memory" {
  default     = "512Mi"
  description = "The memory limit for the Authentik worker"
  type        = string
}

variable "authentik_worker_resources_requests_cpu" {
  description = "The Authentik worker CPU resource request"
  type        = string
}

variable "authentik_worker_resources_requests_memory" {
  description = "The Authentik worker memory resource request"
  type        = string
}

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone for the Kubernetes and Helm providers."

  type = map(object({
    project_id = string
    team_key   = string
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
