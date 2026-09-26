# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "authentik_cloud_sql_proxy_resources_limits_cpu" {
  default     = null
  description = "The CPU limit for the Cloud SQL Auth Proxy sidecar, unset by default so the proxy is never throttled while brokering database connections"
  type        = string
}

variable "authentik_cloud_sql_proxy_resources_limits_memory" {
  default     = "128Mi"
  description = "The memory limit for the Cloud SQL Auth Proxy sidecar"
  type        = string
}

variable "authentik_cloud_sql_proxy_resources_requests_cpu" {
  default     = "50m"
  description = "The CPU request for the Cloud SQL Auth Proxy sidecar"
  type        = string
}

variable "authentik_cloud_sql_proxy_resources_requests_memory" {
  default     = "64Mi"
  description = "The memory request for the Cloud SQL Auth Proxy sidecar"
  type        = string
}

variable "authentik_server_replicas" {
  description = "The number of replicas for the Authentik server"
  type        = number
}

variable "authentik_server_resources_limits_cpu" {
  default     = null
  description = "The CPU limit for the Authentik server, unset by default so request handling is never throttled"
  type        = string
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

variable "authentik_worker_probe_timeout_seconds" {
  default     = 3
  description = "The timeout in seconds for Authentik worker liveness, readiness, and startup probes"
  type        = number
}

variable "authentik_worker_resources_limits_cpu" {
  default     = null
  description = "The CPU limit for the Authentik worker, unset by default so background task processing is never throttled"
  type        = string
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
