output "bootstrap_project_id" {
  value       = var.project_id
  description = "Seed GCP project ID hosting Terraform state and WIF."
}

output "tfstate_bucket_name" {
  value       = google_storage_bucket.tfstate.name
  description = "Hardened GCS bucket name storing foundation Terraform state."
}

output "iac_outputs_bucket_name" {
  value       = google_storage_bucket.iac_outputs.name
  description = "Hardened GCS bucket name storing non-sensitive stage output handoff JSON files."
}

output "wif_pool_name" {
  value       = try(module.github_wif[0].wif_pool_name, null)
  description = "Workload Identity Pool resource name, or null when WIF is disabled."
}

output "wif_provider_name" {
  value       = try(module.github_wif[0].wif_provider_name, null)
  description = "Workload Identity Pool Provider resource name, or null when WIF is disabled."
}

output "ci_service_account_emails" {
  value       = { for k, sa in google_service_account.ci : k => sa.email }
  description = "Map of dedicated CI service account keys to email addresses."
}

output "tf_foundation_ci_sa_email" {
  value       = try(google_service_account.ci["tf_foundation_ci"].email, "")
  description = "Service account email for foundation Terraform CI runs."
}

output "tf_ingestion_ci_sa_email" {
  value       = try(google_service_account.ci["tf_ingestion_ci"].email, "")
  description = "Service account email for ingestion Terraform CI runs."
}

output "dataform_ci_sa_email" {
  value       = try(google_service_account.ci["dataform_ci"].email, "")
  description = "Service account email for Dataform CI checks."
}

output "region" {
  value       = var.region
  description = "Default GCP region propagated to downstream stages."
}

output "prefix" {
  value       = var.prefix
  description = "Naming prefix propagated to downstream stages."
}

output "project_suffix" {
  value       = var.project_suffix
  description = "Uniqueness suffix propagated to downstream stages."
}
