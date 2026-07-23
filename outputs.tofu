# Output Values
# https://opentofu.org/docs/language/values/outputs

output "clusters" {
  description = "Slim GKE cluster map (all teams, all zones) for the deployment workflow to pass to zone workspaces as TF_VAR_clusters, keyed by cluster name"
  value = {
    for cluster_name, cluster_config in local.gke_clusters :
    cluster_name => {
      project_id = cluster_config.project_id
      team_key   = cluster_config.team_key
    }
  }
}

output "gateway_dns" {
  description = "Gateway DNS configuration for Istio per team, keyed by team then DNS zone name"
  value       = local.gateway_dns_by_team
}

output "gke_clusters" {
  description = "GKE clusters aggregated from all teams"
  value       = local.gke_clusters
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_cert" {
  description = "The self-signed certificate for the cert-manager root certificate"
  value       = tls_self_signed_cert.cert_manager_ca.cert_pem
}

output "kubernetes_cert_manager_tls_self_signed_cert_cert_manager_root_key" {
  description = "The private key for the cert-manager root certificate"
  sensitive   = true
  value       = tls_private_key.cert_manager_ca.private_key_pem
}

output "kubernetes_engine_workload_identity_service_account_emails" {
  description = "The email addresses of the service accounts for the Kubernetes namespace workload identity, keyed by team then namespace"
  value = {
    for team_key, google_kubernetes_engine in module.google_kubernetes_engine :
    team_key => google_kubernetes_engine.workload_identity_service_account_emails
  }
}

output "kubernetes_istio_gateway_mci_global_address" {
  description = "The IP address for the Istio Gateway multi-cluster ingress, keyed by team"
  value = {
    for team_key, istio in module.kubernetes_istio :
    team_key => istio.gateway_mci_global_address
  }
}

output "project_id" {
  description = "The platform-managed project ID"
  value       = data.google_project.platform_managed.project_id
}

output "project_number" {
  description = "The platform-managed project number"
  value       = data.google_project.platform_managed.number
}

output "shared_vpc_host_project_id" {
  description = "The shared VPC host project ID from pt-corpus"
  value       = data.google_project.shared_vpc_host.project_id
}

output "team" {
  description = "The team data from helpers module"
  value       = module.core_helpers.teams[module.core_helpers.team]
}
