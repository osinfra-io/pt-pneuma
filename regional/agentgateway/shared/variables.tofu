# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "All GKE clusters from main; only Pneuma gateway clusters in this workspace's zone receive agentgateway"
  type = map(object({
    project_id = string
    team_key   = string
  }))
}

variable "proxy_replicas" {
  default     = 2
  description = "Agentgateway proxy replicas per gateway cluster"
  type        = number

  validation {
    condition     = var.proxy_replicas >= 1 && floor(var.proxy_replicas) == var.proxy_replicas
    error_message = "proxy_replicas must be a positive integer."
  }
}

variable "state_bucket" {
  description = "GCS state bucket supplied by the called deployment workflow"
  type        = string
}

variable "state_kms_encryption_key" {
  description = "State and plan encryption key supplied by the called deployment workflow"
  type        = string
}

variable "state_prefix" {
  description = "State prefix supplied by the called deployment workflow"
  type        = string
}
