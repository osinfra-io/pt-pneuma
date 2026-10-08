# Cloud-free test substitutes. Production locals are symlinked, not copied.

module "core_helpers" {
  source = "../helpers"
}

data "terraform_remote_state" "authentik_config" {
  backend = "local"
}

data "terraform_remote_state" "main" {
  backend = "local"
}

variable "clusters" {
  default = {
    pt-pneuma-us-east1-b = {
      project_id = "mock-project"
      team_key   = "pt-pneuma"
    }
  }
  description = "Cloud-free cluster context used to evaluate the production locals."
  type = map(object({
    project_id = string
    team_key   = string
  }))
}
