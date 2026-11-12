output "root_folder_id" {
  value       = module.folder_hierarchy.root_folder_id
  description = "Root foundation folder resource name."
}

output "shared_infra_folder_id" {
  value       = module.folder_hierarchy.shared_infra_folder_id
  description = "Shared infrastructure folder resource name."
}

output "data_platform_folder_id" {
  value       = module.folder_hierarchy.workload_folder_ids["data-platform"]
  description = "Data platform workload folder resource name."
}

output "data_folder_id" {
  value       = module.folder_hierarchy.workload_folder_ids["data-platform"]
  description = "Alias for data_platform_folder_id consumed by enterprise data stage 01."
}

output "environment_folder_ids" {
  value       = module.folder_hierarchy.environment_folder_ids
  description = "Map of environment names to 02-environments/<env> folder resource names."
}

output "environment_data_platform_folder_ids" {
  value       = module.folder_hierarchy.environment_data_platform_folder_ids
  description = "Map of environment names to per-environment data-platform folder resource names."
}

output "environment_storage_folder_ids" {
  value       = module.folder_hierarchy.environment_storage_folder_ids
  description = "Map of environment names to per-environment storage folder resource names."
}

output "environment_compute_folder_ids" {
  value       = module.folder_hierarchy.environment_compute_folder_ids
  description = "Map of environment names to per-environment compute folder resource names."
}

output "storage_folder_id" {
  value       = module.folder_hierarchy.storage_folder_id
  description = "Default storage folder resource name for backwards compatibility."
}

output "compute_folder_id" {
  value       = module.folder_hierarchy.compute_folder_id
  description = "Default compute folder resource name for backwards compatibility."
}

output "audit_project_id" {
  value       = module.audit_project.project_id
  description = "Central audit logging and FinOps project ID."
}

output "audit_project_number" {
  value       = module.audit_project.project_number
  description = "Numeric audit project number for VPC-SC audit egress."
}

output "audit_project_lien_name" {
  value       = try(google_resource_manager_lien.audit_project[0].name, "")
  description = "Resource Manager deletion lien name on the audit project, or empty string."
}

output "billing_export_dataset_id" {
  value       = module.finops_governance.billing_export_dataset_id
  description = "Central Cloud Billing export BigQuery dataset ID."
}

output "budget_pubsub_topic_id" {
  value       = module.finops_governance.budget_pubsub_topic_id
  description = "Pub/Sub topic ID for FinOps budget alerts."
}

output "budget_name" {
  value       = module.finops_governance.budget_name
  description = "Cloud Billing budget resource name, or null when disabled."
}

output "finops_tag_value_ids" {
  value       = module.finops_governance.finops_tag_value_ids
  description = "Resource Manager FinOps cost-allocation tag value IDs."
}

output "billing_account" {
  value       = var.billing_account
  description = "Billing account ID propagated to downstream stages."
}

output "region" {
  value       = var.region
  description = "Default GCP region propagated to downstream stages."
}

output "dr_region" {
  value       = var.dr_region
  description = "Optional disaster recovery GCP region propagated downstream."
}

output "prefix" {
  value       = var.prefix
  description = "Foundation naming prefix propagated to downstream stages."
}

output "project_suffix" {
  value       = var.project_suffix
  description = "Project uniqueness suffix propagated to downstream stages."
}

output "deletion_protection" {
  value       = var.deletion_protection
  description = "Folder deletion protection setting propagated downstream."
}

output "project_deletion_policy" {
  value       = var.project_deletion_policy
  description = "Project deletion policy propagated downstream."
}

output "log_sink_writer_identity" {
  value       = module.logging_guardrails.log_sink_writer_identity
  description = "Writer service account identity of the folder audit sink."
}

output "log_bucket_id" {
  value       = module.logging_guardrails.log_bucket_id
  description = "Resource ID of the audit Cloud Logging bucket."
}

output "log_analytics_linked_dataset_id" {
  value       = module.logging_guardrails.log_analytics_linked_dataset_id
  description = "BigQuery linked dataset ID for Cloud Logging Log Analytics, or null."
}

output "siem_pubsub_topic_id" {
  value       = module.logging_guardrails.siem_pubsub_topic_id
  description = "Pub/Sub topic ID for optional SIEM log export, or null."
}

output "scc_pubsub_topic_id" {
  value       = module.logging_guardrails.scc_pubsub_topic_id
  description = "Pub/Sub topic ID for SCC v2 high and critical findings, or null."
}

output "enforced_org_policy_names" {
  value       = module.logging_guardrails.enforced_org_policy_names
  description = "Sorted resource names of enforced folder Org Policies."
}

output "delete_contents_on_destroy" {
  value       = var.delete_contents_on_destroy
  description = "Destructive cleanup flag propagated downstream."
}
