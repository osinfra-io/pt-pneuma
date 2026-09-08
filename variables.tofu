# Input Variables
# https://opentofu.org/docs/language/values/variables

# These three state_* variables are required for early variable evaluation for backend and provider configuration.
# They are defined in the GitHub Actions called workflows and should NOT be set in the OpenTofu configuration.

variable "google_oauth_client_id" {
  default     = ""
  description = "OAuth client ID for the optional Google Authentik login source. Sourced from a Google OAuth 2.0 client created manually in the console (see README) - Terraform does not provision this client. Leave empty to disable the source."
  type        = string
}

variable "google_oauth_client_secret" {
  default     = ""
  description = "OAuth client secret for the optional Google Authentik login source. Sourced from a Google OAuth 2.0 client created manually in the console (see README) - Terraform does not provision this client. Leave empty to disable the source."
  sensitive   = true
  type        = string
}

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
