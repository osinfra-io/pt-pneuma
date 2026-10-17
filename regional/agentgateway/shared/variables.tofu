# Input Variables
# https://opentofu.org/docs/language/values/variables

variable "clusters" {
  default     = {}
  description = "All GKE clusters from the main workspace; only the owning team's sandbox clusters in this workspace's zone receive agentgateway."
  type = map(object({
    project_id = string
    team_key   = string
  }))
}
