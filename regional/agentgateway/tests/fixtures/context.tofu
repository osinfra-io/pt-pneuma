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

variable "test_environment" {
  default     = "sandbox"
  description = "Environment selected by the mocked cloud workspace regression."
  type        = string
}

output "cluster_endpoint" {
  description = "Connection endpoint for the single provider."
  value       = local.cluster_endpoint
}

output "clusters" {
  description = "Selected agentgateway deployment clusters."
  value       = local.agentgateway_clusters
}

output "lookup_clusters" {
  description = "Clusters contacted by the production data source."
  value       = keys(data.google_container_cluster.this)
}

output "namespace" {
  description = "Owning team's namespace."
  value       = local.namespace
}
