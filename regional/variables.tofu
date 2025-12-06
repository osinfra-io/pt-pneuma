# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "kubernetes_engine_master_ipv4_cidr_block" {
  description = "The IP range in CIDR notation to use for the hosted master network"
  type        = string
}

variable "kubernetes_engine_network" {
  description = "The network to use for the GKE cluster"
  type        = string
}

variable "kubernetes_engine_vpc_host_project_id" {
  description = "Host project for the shared VPC"
  type        = string
}

variable "remote_bucket" {
  description = "The remote bucket the `terraform_remote_state` data source retrieves the state from"
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
