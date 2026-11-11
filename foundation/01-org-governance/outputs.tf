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

output "audit_project_id" {
  value       = module.audit_project.project_id
  description = "Central audit logging and FinOps project ID."
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

output "enforced_org_policy_names" {
  value       = module.logging_guardrails.enforced_org_policy_names
  description = "Sorted resource names of enforced folder Org Policies."
}

output "delete_contents_on_destroy" {
  value       = var.delete_contents_on_destroy
  description = "Destructive cleanup flag propagated downstream."
}
