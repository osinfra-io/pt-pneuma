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

variable "kubernetes_datadog_aap_extproc_resources_limits_cpu" {
  default     = "100m"
  description = "The CPU limit for the Datadog App and API Protection external processor"
  type        = string
}

variable "kubernetes_datadog_aap_extproc_resources_limits_memory" {
  default     = "256Mi"
  description = "The memory limit for the Datadog App and API Protection external processor"
  type        = string
}

variable "kubernetes_datadog_aap_extproc_resources_requests_cpu" {
  default     = "50m"
  description = "The CPU request for the Datadog App and API Protection external processor"
  type        = string
}

variable "kubernetes_datadog_aap_extproc_resources_requests_memory" {
  default     = "128Mi"
  description = "The memory request for the Datadog App and API Protection external processor"
  type        = string
}

variable "kubernetes_istio_cni_cpu_limits" {
  default     = null
  description = "The CPU limit for the Istio CNI node agent, unset by default to match the upstream chart which ships requests only"
  type        = string
}

variable "kubernetes_istio_cni_cpu_requests" {
  default     = "100m"
  description = "The CPU request for the Istio CNI node agent"
  type        = string
}

variable "kubernetes_istio_cni_memory_limits" {
  default     = null
  description = "The memory limit for the Istio CNI node agent, unset by default to match the upstream chart which ships requests only"
  type        = string
}

variable "kubernetes_istio_cni_memory_requests" {
  default     = "100Mi"
  description = "The memory request for the Istio CNI node agent"
  type        = string
}

variable "kubernetes_istio_east_west_gateway_cpu_limits" {
  default     = "2"
  description = "The CPU limit for the Istio east-west gateway"
  type        = string
}

variable "kubernetes_istio_east_west_gateway_cpu_requests" {
  default     = "100m"
  description = "The CPU request for the Istio east-west gateway"
  type        = string
}

variable "kubernetes_istio_east_west_gateway_memory_limits" {
  default     = "1Gi"
  description = "The memory limit for the Istio east-west gateway"
  type        = string
}

variable "kubernetes_istio_east_west_gateway_memory_requests" {
  default     = "128Mi"
  description = "The memory request for the Istio east-west gateway"
  type        = string
}

variable "kubernetes_istio_gateway_autoscale_max" {
  default     = 5
  description = "The maximum number of gateway replicas to run"
  type        = number
}

variable "kubernetes_istio_gateway_autoscale_min" {
  default     = 1
  description = "The minimum number of gateway replicas to run"
  type        = number
}

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

variable "kubernetes_istio_pilot_autoscale_max" {
  default     = 5
  description = "The maximum number of Istio pilot replicas to run"
  type        = number
}

variable "kubernetes_istio_pilot_autoscale_min" {
  default     = 1
  description = "The minimum number of Istio pilot replicas to run"
  type        = number
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

variable "kubernetes_istio_pilot_replica_count" {
  default     = 1
  description = "The number of Istio pilot replicas to run"
  type        = number
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

variable "kubernetes_istio_ztunnel_cpu_limits" {
  default     = "500m"
  description = "The CPU limit for ztunnel"
  type        = string
}

variable "kubernetes_istio_ztunnel_cpu_requests" {
  default     = "250m"
  description = "The CPU request for ztunnel"
  type        = string
}

variable "kubernetes_istio_ztunnel_memory_limits" {
  default     = "512Mi"
  description = "The memory limit for ztunnel"
  type        = string
}

variable "kubernetes_istio_ztunnel_memory_requests" {
  default     = "256Mi"
  description = "The memory request for ztunnel"
  type        = string
}
