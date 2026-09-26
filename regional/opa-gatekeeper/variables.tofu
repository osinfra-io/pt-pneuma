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

# The audit controller measures a steady 40m CPU and 96Mi memory, which is exactly its module
# default CPU limit (40m) and 75% of its memory limit (128Mi) - it is throttled continuously
# and has little memory headroom. Limits do not consume scheduling budget, so both are raised.
# Audit requests stay at the module defaults: the controller overruns them, but our nodes run
# at roughly 46% CPU so there is no contention.

variable "kubernetes_opa_gatekeeper_audit_cpu_limits" {
  default     = "150m"
  description = "The CPU limit for the Gatekeeper audit controller"
  type        = string
}

variable "kubernetes_opa_gatekeeper_audit_memory_limits" {
  default     = "256Mi"
  description = "The memory limit for the Gatekeeper audit controller"
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
