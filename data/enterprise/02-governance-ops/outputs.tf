output "dataform_repository_name" {
  value       = module.dataform_repository.repository_name
  description = "Dataform repository short name in data-etl."
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
  description = "Google-managed Dataform service agent email in data-etl."
}

output "dataplex_service_agent_email" {
  value       = google_project_service_identity.dataplex_agent.email
  description = "Google-managed Dataplex service agent email in the Gold project."
}

output "dataplex_scan_names" {
  value       = module.dataplex_scans.scan_names
  description = "Map of Dataplex data profile scan resource names."
}

output "ops_telemetry_dataset_id" {
  value       = google_bigquery_dataset.ops_telemetry.dataset_id
  description = "Operational telemetry BigQuery dataset ID in data-etl."
}

output "ops_view_id" {
  value       = google_bigquery_table.ops_job_cost_monitor.id
  description = "Resource ID of the operational job cost monitor view."
}
