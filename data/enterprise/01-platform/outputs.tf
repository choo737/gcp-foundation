output "storage_folder_id" {
  value       = google_folder.storage.name
  description = "Enterprise data storage subfolder resource name."
}

output "compute_folder_id" {
  value       = google_folder.compute.name
  description = "Enterprise data compute subfolder resource name."
}

output "governance_project_id" {
  value       = module.data_gov.project_id
  description = "Data governance project ID."
}

output "core_storage_project_id" {
  value       = module.data_core.project_id
  description = "Core Bronze and Silver storage project ID."
}

output "domain_storage_project_ids" {
  value       = { for k, m in module.data_domain : k => m.project_id }
  description = "Map of domain codes to Gold mart storage project IDs."
}

output "domain_storage_project_numbers" {
  value       = { for k, m in module.data_domain : k => m.project_number }
  description = "Map of domain codes to Gold mart storage project numbers."
}

output "data_platform_project_numbers" {
  value = concat(
    [
      module.data_gov.project_number,
      module.data_core.project_number,
      module.data_etl.project_number,
      module.data_bi.project_number,
    ],
    [for k in sort(keys(module.data_domain)) : module.data_domain[k].project_number],
  )
  description = "List of numeric project numbers across all data platform projects."
}

output "primary_gold_project_id" {
  value       = module.data_domain[var.primary_domain].project_id
  description = "Primary domain Gold mart storage project ID."
}

output "etl_compute_project_id" {
  value       = module.data_etl.project_id
  description = "ETL compute project ID hosting Dataform and reservations."
}

output "bi_compute_project_id" {
  value       = module.data_bi.project_id
  description = "BI query compute project ID."
}

output "landing_bucket_name" {
  value       = google_storage_bucket.landing.name
  description = "Raw ingestion landing Cloud Storage bucket name."
}

output "bronze_dataset_id" {
  value       = module.core_datasets["bronze_raw"].dataset_id
  description = "Core Bronze dataset ID."
}

output "silver_dataset_id" {
  value       = module.core_datasets["silver_curated"].dataset_id
  description = "Core Silver curated dataset ID."
}

output "assertions_dataset_id" {
  value       = module.core_datasets["silver_assertions"].dataset_id
  description = "Core Silver assertions dataset ID."
}

output "primary_gold_dataset_id" {
  value       = module.domain_gold_mart[var.primary_domain].dataset_id
  description = "Primary domain Gold mart dataset ID."
}

output "domain_gold_dataset_ids" {
  value       = { for k, m in module.domain_gold_mart : k => m.dataset_id }
  description = "Map of domain codes to Gold mart dataset IDs."
}

output "taxonomy_id" {
  value       = module.governance_catalog.taxonomy_id
  description = "Data Catalog PII taxonomy resource ID."
}

output "pii_restricted_policy_tag_id" {
  value       = module.governance_catalog.pii_restricted_policy_tag_id
  description = "Resource name of the restricted PII policy tag."
}

output "pii_masked_policy_tag_id" {
  value       = module.governance_catalog.pii_masked_policy_tag_id
  description = "Resource name of the masked PII policy tag."
}

output "pii_data_policy_id" {
  value       = module.governance_catalog.pii_data_policy_id
  description = "Full resource ID of the BigQuery PII data masking policy."
}

output "pii_data_policy_short_id" {
  value       = module.governance_catalog.pii_data_policy_short_id
  description = "Short data_policy_id of the BigQuery PII data masking policy."
}

output "glossary_id" {
  value       = module.governance_catalog.glossary_id
  description = "Dataplex business glossary resource ID."
}

output "reservation_ids" {
  value       = try(module.reservations[0].reservation_ids, {})
  description = "Map of BigQuery Enterprise reservation IDs."
}

output "kms_key_id" {
  value       = var.kms_key_id
  description = "Optional regional CMEK crypto key ID propagated to stage 02."
}

output "region" {
  value       = var.region
  description = "GCP region propagated to stage 02."
}

output "prefix" {
  value       = var.prefix
  description = "Platform prefix propagated to stage 02."
}

output "delete_contents_on_destroy" {
  value       = var.delete_contents_on_destroy
  description = "Destructive cleanup flag propagated to stage 02."
}
