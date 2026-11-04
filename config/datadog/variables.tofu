# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name."

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

variable "datadog_synthetic_status" {
  default     = "paused"
  description = "The status of Datadog synthetic tests"
  type        = string

  validation {
    condition     = contains(["live", "paused"], var.datadog_synthetic_status)
    error_message = "Datadog synthetic tests must be either live or paused."
  }
}
