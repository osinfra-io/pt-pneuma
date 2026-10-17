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

variable "kubernetes_cert_manager_istio_csr_resources_limits_cpu" {
  default     = "100m"
  description = "The CPU limit for the Istio CSR container"
  type        = string
}

variable "kubernetes_cert_manager_istio_csr_resources_limits_memory" {
  default     = "128Mi"
  description = "The memory limit for the Istio CSR container"
  type        = string
}

variable "kubernetes_cert_manager_istio_csr_resources_requests_cpu" {
  default     = "25m"
  description = "The CPU request for the Istio CSR container"
  type        = string
}

variable "kubernetes_cert_manager_istio_csr_resources_requests_memory" {
  default     = "64Mi"
  description = "The memory request for the Istio CSR container"
  type        = string
}
