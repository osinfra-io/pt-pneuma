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

variable "kubernetes_opa_gatekeeper_audit_resources_limits_cpu" {
  default     = "150m"
  description = "The CPU limit for the audit container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_audit_resources_limits_memory" {
  default     = "256Mi"
  description = "The memory limit for the audit container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_audit_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the audit container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_audit_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the audit container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_controller_manager_resources_limits_cpu" {
  default     = "100m"
  description = "The CPU limit for the controller manager container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_controller_manager_resources_limits_memory" {
  default     = "256Mi"
  description = "The memory limit for the controller manager container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_controller_manager_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the controller manager container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_controller_manager_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the controller manager container"
  type        = string
}

variable "kubernetes_opa_gatekeeper_replicas" {
  default     = 1
  description = "The number of Gatekeeper controller manager replicas to run"
  type        = number
}
