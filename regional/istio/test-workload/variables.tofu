# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone for the Kubernetes provider."

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

variable "datadog_synthetic_dns_domain" {
  description = "The DNS domain used by Datadog synthetic tests"
  type        = string
}

variable "datadog_synthetic_message_critical" {
  description = "Datadog notification message for critical synthetic tests"
  type        = string
}

variable "datadog_synthetic_message_medium" {
  description = "Datadog notification message for medium-priority synthetic tests"
  type        = string
}

variable "istio_test_replicas" {
  default     = 1
  description = "The number of replicas for the istio-test deployment"
  type        = number
}

variable "istio_test_version" {
  default     = "v0.4.1"
  description = "The version of the istio-test deployment"
  type        = string
}

variable "kubernetes_istio_test_resources_limits_cpu" {
  default     = "20m"
  description = "The CPU limit for the Istio test workload"
  type        = string
}

variable "kubernetes_istio_test_resources_limits_memory" {
  default     = "64Mi"
  description = "The memory limit for the Istio test workload"
  type        = string
}

variable "kubernetes_istio_test_resources_requests_cpu" {
  default     = "10m"
  description = "The CPU request for the Istio test workload"
  type        = string
}

variable "kubernetes_istio_test_resources_requests_memory" {
  default     = "32Mi"
  description = "The memory request for the Istio test workload"
  type        = string
}
