output "app_folder_ids" {
  value       = { for k, f in google_folder.app_unit : k => f.name }
  description = "Map of application keys to per-application folder resource names."
}

output "app_project_ids" {
  value       = { for k, m in module.app_project : k => m.project_id }
  description = "Map of application keys to provisioned GCP project IDs."
}

output "app_project_numbers" {
  value       = { for k, m in module.app_project : k => m.project_number }
  description = "Map of application keys to numeric GCP project numbers."
}

output "app_runtime_sa_emails" {
  value       = { for k, sa in google_service_account.app_runtime : k => sa.email }
  description = "Map of application keys to dedicated least-privilege runtime service account emails."
}

output "gke_node_sa_emails" {
  value       = { for k, sa in google_service_account.gke_node : k => sa.email }
  description = "Map of GKE-enabled application keys to dedicated least-privilege GKE node service account emails."
}

output "compute_service_agent_members" {
  value       = { for k, sa in google_project_service_identity.compute : k => sa.member }
  description = "Map of application keys to materialized Compute Engine service agent IAM members."
}

output "cloudrun_service_agent_members" {
  value       = { for k, sa in google_project_service_identity.cloudrun : k => sa.member }
  description = "Map of Cloud Run-enabled application keys to materialized Cloud Run service agent IAM members."
}

output "gke_service_agent_members" {
  value       = { for k, sa in google_project_service_identity.gke : k => sa.member }
  description = "Map of GKE-enabled application keys to materialized GKE service agent IAM members."
}
