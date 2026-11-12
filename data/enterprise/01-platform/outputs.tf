output "storage_folder_id" {
  value       = local.effective_storage_folder_id
  description = "Enterprise data storage subfolder resource name."
}

output "compute_folder_id" {
  value       = local.effective_compute_folder_id
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
  description = "ETL compute project ID hosting Dataform, Artifact Registry, and reservations."
}

output "bi_compute_project_id" {
  value       = module.data_bi.project_id
  description = "BI query compute project ID."
}

output "landing_bucket_name" {
  value       = google_storage_bucket.landing.name
  description = "Raw ingestion landing Cloud Storage bucket name."
}

output "artifact_registry_repository_uri" {
  value       = "${var.region}-docker.pkg.dev/${module.data_etl.project_id}/${google_artifact_registry_repository.ingestion.repository_id}"
  description = "Docker Artifact Registry URI in data-etl for ingestion containers."
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

output "quarantine_dataset_id" {
  value       = module.core_datasets["quarantine"].dataset_id
  description = "Core quarantine dataset ID."
}

output "primary_gold_dataset_id" {
  value       = module.domain_gold_mart[var.primary_domain].dataset_id
  description = "Primary domain Gold mart dataset ID."
}

output "domain_gold_dataset_ids" {
  value       = { for k, m in module.domain_gold_mart : k => m.dataset_id }
  description = "Map of domain codes to Gold mart dataset IDs."
}

output "dr_dataset_ids" {
  value = merge(
    { for k, m in module.core_dr_datasets : k => m.dataset_id },
    { for k, m in module.domain_gold_mart_dr : "gold_${k}" => m.dataset_id },
  )
  description = "Map of optional DR BigQuery dataset IDs when enable_dr_datasets is true."
}

output "dataform_custom_role_ids" {
  value = merge(
    {
      (module.data_core.project_id) = google_project_iam_custom_role.dataform_runner_core.id
      (module.data_bi.project_id)   = google_project_iam_custom_role.dataform_runner_bi.id
    },
    { for k, r in google_project_iam_custom_role.dataform_runner_domain : module.data_domain[k].project_id => r.id },
  )
  description = "Map of data project IDs to custom dataform_pipeline_runner role IDs."
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

output "dr_kms_key_id" {
  value       = var.dr_kms_key_id
  description = "Optional secondary DR CMEK crypto key ID propagated downstream."
}

output "shared_vpc_host_project_id" {
  value       = var.shared_vpc_host_project_id
  description = "Shared VPC host project ID propagated downstream."
}

output "vpc_id" {
  value       = var.vpc_id
  description = "Custom VPC network resource ID propagated to downstream ingestion repos."
}

output "subnet_id" {
  value       = var.subnet_id
  description = "Private subnetwork resource ID propagated to downstream ingestion repos."
}

output "datastream_network_attachment_id" {
  value       = var.datastream_network_attachment_id
  description = "Datastream PSC network attachment ID propagated downstream."
}

output "vpc_sc_perimeter_name" {
  value       = var.vpc_sc_perimeter_name
  description = "VPC-SC perimeter resource name propagated to stage 02."
}

output "enforce_vpc_sc" {
  value       = var.enforce_vpc_sc
  description = "VPC-SC enforcement flag propagated to stage 02."
}

output "environment" {
  value       = var.environment
  description = "Lifecycle environment propagated to stage 02."
}

output "region" {
  value       = var.region
  description = "GCP region propagated to stage 02."
}

output "dr_region" {
  value       = var.dr_region
  description = "Optional DR region propagated downstream."
}

output "prefix" {
  value       = var.prefix
  description = "Platform prefix propagated to stage 02."
}

output "delete_contents_on_destroy" {
  value       = var.delete_contents_on_destroy
  description = "Destructive cleanup flag propagated to stage 02."
}
