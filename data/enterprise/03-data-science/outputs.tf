output "ds_exp_project_id" {
  value       = local.effective_ds_exp_project_id
  description = "Data science experimentation project ID."
}

output "ml_ops_project_id" {
  value       = local.effective_ml_ops_project_id
  description = "MLOps serving and XAI audit project ID."
}

output "ml_artifact_repo_id" {
  value       = try(module.ml_governance[0].ml_artifact_repo_id, "")
  description = "Docker Artifact Registry repository ID for custom inference routines."
}

output "ml_audit_dataset_id" {
  value       = try(module.ml_governance[0].ml_audit_dataset_id, "")
  description = "BigQuery dataset ID hosting ml_xai_audit_ledger."
}

output "ml_audit_table_id" {
  value       = try(module.ml_governance[0].ml_audit_table_id, "")
  description = "BigQuery table ID of the 18-column XAI audit ledger."
}

output "ml_training_labels_table_id" {
  value       = try(module.ml_governance[0].ml_training_labels_table_id, "")
  description = "BigQuery table ID of the governed point-in-time training labels table."
}

output "vertex_psc_service_connection_policy_id" {
  value       = local.trimmed_upstream_vertex_psc != "" ? local.trimmed_upstream_vertex_psc : try(module.ml_governance[0].vertex_psc_service_connection_policy_id, "")
  description = "Network Connectivity Service Connection Policy resource ID for Agent Platform PSC automation."
}

output "ml_worm_bucket_name" {
  value       = try(module.ml_governance[0].ml_worm_bucket_name, "")
  description = "Locked WORM GCS bucket name for XAI audit archives."
}

output "shap_additivity_tolerance" {
  value       = try(module.ml_governance[0].shap_additivity_tolerance, var.shap_additivity_tolerance)
  description = "SHAP logit additivity tolerance epsilon."
}

output "workbench_instance_names" {
  value       = try(module.ml_governance[0].workbench_instance_names, {})
  description = "Map of Workbench instance keys to provisioned resource names."
}

output "colab_runtime_template_id" {
  value       = try(module.ml_governance[0].colab_runtime_template_id, "")
  description = "Colab Enterprise runtime template resource ID when enabled."
}

output "metadata_store_id" {
  value       = try(module.ml_governance[0].metadata_store_id, "")
  description = "Agent Platform ML Metadata Store resource ID."
}

output "xai_quality_scan_id" {
  value       = try(module.ml_governance[0].xai_quality_scan_id, "")
  description = "Knowledge Catalog Auto data quality scan resource ID on ml_xai_audit_ledger."
}

output "workbench_runtime_sa_email" {
  value       = try(google_service_account.workbench_runtime[0].email, "")
  description = "Custom runtime service account email attached to Workbench instances."
}

output "core_storage_project_id" {
  value       = var.core_storage_project_id
  description = "Core Bronze and Silver storage project ID propagated downstream."
}

output "silver_dataset_id" {
  value       = var.silver_dataset_id
  description = "Core Silver curated dataset ID propagated downstream."
}

output "kms_key_id" {
  value       = var.kms_key_id
  description = "Optional regional CMEK crypto key ID propagated downstream."
}

output "vpc_id" {
  value       = var.vpc_id
  description = "Custom VPC network resource ID propagated downstream."
}

output "subnet_id" {
  value       = var.subnet_id
  description = "Private subnetwork resource ID propagated downstream."
}

output "ds_subnet_id" {
  value       = var.subnet_id
  description = "AI and Data Science subnetwork resource ID."
}

output "notification_channel_ids" {
  value       = var.notification_channel_ids
  description = "Cloud Monitoring notification channel IDs propagated downstream."
}

output "region" {
  value       = var.region
  description = "GCP region propagated downstream."
}

output "prefix" {
  value       = var.prefix
  description = "Naming prefix propagated downstream."
}

output "project_suffix" {
  value       = local.effective_project_suffix
  description = "Effective project uniqueness suffix propagated downstream."
}

output "environment" {
  value       = var.environment
  description = "Lifecycle environment propagated downstream."
}
