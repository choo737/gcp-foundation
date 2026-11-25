output "dataform_repository_name" {
  value       = module.dataform_repository.repository_name
  description = "Dataform repository short name in etl_compute_project_id."
}

output "additional_dataform_repository_names" {
  value       = { for k, m in module.additional_dataform_repository : k => m.repository_name }
  description = "Map of additional Dataform repository short names keyed by business unit."
}

output "dataform_release_config_name" {
  value       = module.dataform_repository.release_config_name
  description = "Dataform release configuration name."
}

output "dataform_workflow_config_name" {
  value       = module.dataform_repository.workflow_config_name
  description = "Dataform workflow configuration name, or empty string when disabled."
}

output "dataform_service_account_email" {
  value       = module.dataform_repository.service_account_email
  description = "Dedicated Dataform ETL service account email."
}

output "dataform_service_agent_email" {
  value       = google_project_service_identity.dataform_agent.email
  description = "Google-managed Dataform service agent email in etl_compute_project_id."
}

output "dataplex_service_agent_email" {
  value       = google_project_service_identity.dataplex_agent.email
  description = "Google-managed Knowledge Catalog service agent email in the Gold project."
}

output "dataplex_scan_names" {
  value = merge(
    module.dataplex_scans.scan_names,
    { for k, m in module.additional_quality_scans : k => m.quality_scan_name },
  )
  description = "Map of Knowledge Catalog data profile and additional quality scan resource names."
}

output "quality_scan_id" {
  value       = module.dataplex_scans.quality_scan_id
  description = "Knowledge Catalog data quality scan ID for Silver orders."
}

output "dataplex_quality_scan_id" {
  value       = module.dataplex_scans.dataplex_quality_scan_id
  description = "Alias of quality_scan_id for downstream orchestration stages."
}

output "additional_quality_scan_ids" {
  value       = { for k, m in module.additional_quality_scans : k => m.quality_scan_id }
  description = "Map of additional declarative Knowledge Catalog quality scan IDs."
}

output "ops_telemetry_dataset_id" {
  value       = google_bigquery_dataset.ops_telemetry.dataset_id
  description = "Operational telemetry BigQuery dataset ID in etl_compute_project_id."
}

output "ops_view_id" {
  value       = google_bigquery_table.ops_job_cost_monitor.id
  description = "Resource ID of the operational job cost monitor view."
}

output "workload_alert_policy_ids" {
  value       = module.monitoring_alerts.alert_policy_ids
  description = "Cloud Monitoring alert policy resource IDs monitoring enterprise data workload projects."
}
