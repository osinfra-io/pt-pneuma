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

variable "google_oauth_client_id" {
  default     = ""
  description = "OAuth client ID for the optional Google Authentik login source. Set this non-sensitive value in the environment tfvars from a Google OAuth 2.0 client created manually in the console. Leave empty to disable the source."
  type        = string
}

variable "google_oauth_client_secret" {
  default     = ""
  description = "OAuth client secret for the optional Google Authentik login source. Supply this value through the deployment workflow's secret plan arguments. Leave empty to disable the source."
  sensitive   = true
  type        = string
}

variable "sandbox_authentication_enabled" {
  description = "Enable the sandbox-specific Authentik authentication flow and brand"
  type        = bool
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
