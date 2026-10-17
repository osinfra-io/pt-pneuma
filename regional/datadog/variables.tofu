# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone for the Helm provider."

  type = map(object({
    project_id = string
    team_key   = string
  }))
}

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

variable "kubernetes_datadog_operator_limits_cpu" {
  default     = "200m"
  description = "The CPU limit for the Datadog operator"
  type        = string
}

variable "kubernetes_datadog_operator_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the Datadog operator"
  type        = string
}

variable "kubernetes_datadog_operator_requests_cpu" {
  default     = "100m"
  description = "The CPU request for the Datadog operator"
  type        = string
}

variable "kubernetes_datadog_operator_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the Datadog operator"
  type        = string
}
