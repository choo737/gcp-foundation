output "workbench_instance_names" {
  value       = { for k, inst in google_workbench_instance.this : k => inst.name }
  description = "Map of Workbench instance keys to provisioned resource names."
}

output "colab_runtime_template_id" {
  value       = try(google_colab_runtime_template.this[0].id, "")
  description = "Colab Enterprise runtime template resource ID when enabled."
}

output "ml_artifact_repo_id" {
  value       = google_artifact_registry_repository.ml_cpr.repository_id
  description = "Docker Artifact Registry repository ID for custom inference routines."
}

output "ml_artifact_repo_uri" {
  value       = "${var.region}-docker.pkg.dev/${var.ml_ops_project_id}/${google_artifact_registry_repository.ml_cpr.repository_id}"
  description = "Full Docker registry URI for custom inference routines."
}

output "metadata_store_id" {
  value       = google_vertex_ai_metadata_store.default.id
  description = "Agent Platform ML Metadata Store resource ID."
}

output "ml_worm_bucket_name" {
  value       = google_storage_bucket.xai_worm.name
  description = "Locked WORM Cloud Storage bucket name for XAI audit archives."
}

output "ml_audit_dataset_id" {
  value       = google_bigquery_dataset.ml_xai_audit.dataset_id
  description = "BigQuery dataset ID hosting the XAI audit ledger."
}

output "ml_audit_table_id" {
  value       = google_bigquery_table.ml_xai_audit_ledger.table_id
  description = "BigQuery table ID of the 18-column XAI audit ledger."
}

output "ml_training_labels_table_id" {
  value       = google_bigquery_table.ml_training_labels.table_id
  description = "BigQuery table ID of the governed point-in-time training labels table."
}

output "vertex_psc_service_connection_policy_id" {
  value       = try(google_network_connectivity_service_connection_policy.vertex_psc[0].id, "")
  description = "Network Connectivity Service Connection Policy resource ID for Agent Platform PSC automation."
}

output "xai_quality_scan_id" {
  value       = try(google_dataplex_datascan.xai_audit[0].id, "")
  description = "Knowledge Catalog Auto data quality scan resource ID on ml_xai_audit_ledger."
}

output "shap_additivity_tolerance" {
  value       = var.shap_additivity_tolerance
  description = "Configured SHAP logit additivity tolerance epsilon."
}
