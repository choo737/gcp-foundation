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

output "org_gov_ci_sa_email" {
  value       = try(google_service_account.ci["org_gov_ci"].email, "")
  description = "Service account email for foundation/01-org-governance Terraform CI runs in per_stage mode."
}

output "net_sec_ci_sa_email" {
  value       = try(google_service_account.ci["net_sec_ci"].email, "")
  description = "Service account email for foundation/02-security-network Terraform CI runs in per_stage mode."
}

output "data_plat_ci_sa_email" {
  value       = try(google_service_account.ci["data_plat_ci"].email, "")
  description = "Service account email for data/enterprise Terraform CI runs in per_stage mode."
}

output "tf_ingestion_ci_sa_email" {
  value       = try(google_service_account.ci["tf_ingestion_ci"].email, "")
  description = "Service account email for ingestion Terraform CI runs."
}

output "dataform_ci_sa_email" {
  value       = try(google_service_account.ci["dataform_ci"].email, "")
  description = "Service account email for Dataform CI checks."
}

output "tf_ds_ci_sa_email" {
  value       = try(google_service_account.ci["tf_ds_ci"].email, "")
  description = "Service account email for Data Science Terraform CI runs."
}

output "tf_app_ci_sa_email" {
  value       = try(google_service_account.ci["tf_app_ci"].email, "")
  description = "Service account email for Application Factory Terraform CI runs."
}

output "secops_ci_sa_email" {
  value       = try(google_service_account.ci["secops_ci"].email, "")
  description = "Service account email for SecOps Terraform CI runs."
}

output "finops_ci_sa_email" {
  value       = try(google_service_account.ci["finops_ci"].email, "")
  description = "Service account email for FinOps Terraform CI runs."
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

output "day0_iam_grant_commands" {
  value = compact(concat(
    local.numeric_org_id == "" ? [
      for _, binding in local.active_org_iam_bindings :
      "gcloud organizations add-iam-policy-binding <ORG_ID> --member=\"serviceAccount:${google_service_account.ci[binding.sa_key].email}\" --role=\"${binding.role}\""
    ] : [],
    local.trimmed_billing_account == "" ? [
      for _, binding in local.active_billing_iam_bindings :
      "gcloud billing accounts add-iam-policy-binding <BILLING_ACCOUNT_ID> --member=\"serviceAccount:${google_service_account.ci[binding.sa_key].email}\" --role=\"${binding.role}\""
    ] : [],
  ))
  description = "Exact Day-0 gcloud IAM grant commands when organization_id or billing_account are omitted from bootstrap."
}
