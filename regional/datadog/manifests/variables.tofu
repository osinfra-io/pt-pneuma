# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone for the per-cluster providers."

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

variable "datadog_enable" {
  default     = false
  description = "Platform kill switch for the Datadog agent manifests on all clusters. Enabled only in environments whose tfvars set it to true (production), to avoid host costs."
  type        = bool
}

variable "kubernetes_datadog_operator_cluster_agent_limits_cpu" {
  default     = "200m"
  description = "CPU limits for the Datadog cluster agent"
  type        = string
}

variable "kubernetes_datadog_operator_cluster_agent_limits_memory" {
  default     = "256Mi"
  description = "Memory limits for the Datadog cluster agent"
  type        = string
}

variable "kubernetes_datadog_operator_cluster_agent_requests_cpu" {
  default     = "100m"
  description = "CPU requests for the Datadog cluster agent"
  type        = string
}

variable "kubernetes_datadog_operator_cluster_agent_requests_memory" {
  default     = "128Mi"
  description = "Memory requests for the Datadog cluster agent"
  type        = string
}

variable "kubernetes_datadog_operator_node_agent_container_resources" {
  default     = {}
  description = "Optional resource requests and limits for specific Datadog Node Agent containers, keyed by container name"
  type = map(object({
    limits   = map(string)
    requests = map(string)
  }))
}
