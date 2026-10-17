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
