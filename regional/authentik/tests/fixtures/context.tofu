terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

module "core_helpers" {
  source = "./helpers"

  environment = var.test_environment
}

variable "clusters" {
  type = map(object({
    project_id = string
    team_key   = string
  }))
}

variable "test_environment" {
  default = "sandbox"
  type    = string
}

output "cluster_endpoint" {
  value = local.cluster_endpoint
}

output "lookup_clusters" {
  value = keys(data.google_container_cluster.this)
}
