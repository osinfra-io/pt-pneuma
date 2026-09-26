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

# The module default (25m) is an order of magnitude above observed usage: istio-csr signs
# workload certificates on demand and measures 3m CPU. This request reclaims that headroom on
# our single-node clusters. The module's limit (50m) is unchanged, so signing bursts are still
# absorbed.

variable "kubernetes_cert_manager_istio_csr_cpu_requests" {
  default     = "10m"
  description = "The CPU request for cert-manager istio-csr"
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
