# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "GKE clusters (all teams, all zones) from the main workspace, keyed by cluster name. Passed by the deployment workflow as TF_VAR_clusters from the main workspace's clusters output; filtered to this zone and team for the Helm providers."

  type = map(object({
    project_id = string
    team_key   = string
  }))
}

variable "openbao_helm_set_values" {
  default     = []
  description = "Environment-specific OpenBao Helm set values"

  type = list(object({
    name  = string
    value = string
  }))
}

variable "openbao_version" {
  default     = "0.27.0"
  description = "The version of the OpenBao Helm chart to deploy"
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
