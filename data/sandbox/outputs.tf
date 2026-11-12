output "project_id" {
  value       = var.project_id
  description = "Sandbox GCP project ID."
}

output "region" {
  value       = var.region
  description = "Sandbox GCP region."
}

output "prefix" {
  value       = var.prefix
  description = "Sandbox naming prefix."
}

output "project_number" {
  value       = data.google_project.current.number
  description = "Numeric GCP project number for the sandbox project."
}

output "dataset_ids" {
  value       = { for k, m in module.datasets : k => m.dataset_id }
  description = "Map of Medallion layer keys to created BigQuery dataset IDs."
}

output "bronze_dataset_id" {
  value       = module.datasets["bronze_raw"].dataset_id
  description = "Sandbox Bronze BigQuery dataset ID."
}

output "ops_telemetry_dataset_id" {
  value       = module.datasets["ops_telemetry"].dataset_id
  description = "Sandbox operational telemetry BigQuery dataset ID."
}

output "taxonomy_id" {
  value       = module.governance_catalog.taxonomy_id
  description = "Data Catalog PII taxonomy ID."
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
  description = "Resource ID of the BigQuery PII data masking policy."
}

output "glossary_id" {
  value       = module.governance_catalog.glossary_id
  description = "Dataplex business glossary resource ID."
}

output "dataplex_scan_names" {
  value       = module.dataplex_scans.scan_names
  description = "Map of Dataplex data profile scan resource names."
}

output "dataform_repository_name" {
  value       = module.dataform_repository.repository_name
  description = "Dataform repository short name."
}

output "dataform_release_config_name" {
  value       = module.dataform_repository.release_config_name
  description = "Dataform release configuration name."
}

output "dataform_service_account_email" {
  value       = module.dataform_repository.service_account_email
  description = "Dedicated Dataform ETL service account email."
}

output "dataform_service_agent_email" {
  value       = google_project_service_identity.dataform_agent.email
  description = "Google-managed Dataform service agent email."
}

output "dataplex_service_agent_email" {
  value       = google_project_service_identity.dataplex_agent.email
  description = "Google-managed Dataplex service agent email."
}
