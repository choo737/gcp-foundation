output "parent_id" {
  value       = var.parent_id
  description = "Root organization or parent folder ID."
}

output "root_folder_id" {
  value       = module.folder_hierarchy.root_folder_id
  description = "Root organization or parent folder resource name."
}

output "shared_infra_folder_id" {
  value       = module.folder_hierarchy.shared_infra_folder_id
  description = "fldr-coe folder resource name."
}

output "coe_folder_id" {
  value       = module.folder_hierarchy.coe_folder_id
  description = "Alias for shared_infra_folder_id (fldr-coe folder resource name)."
}

output "network_folder_id" {
  value       = module.folder_hierarchy.network_folder_id
  description = "Top-level fldr-network folder resource name."
}

output "create_data_subfolders" {
  value       = var.create_data_subfolders
  description = "Whether data platform stages create fldr-<env>-storage and fldr-<env>-compute subfolders."
}

output "data_platform_folder_id" {
  value       = length(var.environments) > 0 ? lookup(module.folder_hierarchy.environment_data_platform_folder_ids, contains(var.environments, "prod") ? "prod" : var.environments[0], "") : ""
  description = "Default environment fldr-<env>-data-platform folder resource name."
}

output "data_folder_id" {
  value       = length(var.environments) > 0 ? lookup(module.folder_hierarchy.environment_data_platform_folder_ids, contains(var.environments, "prod") ? "prod" : var.environments[0], "") : ""
  description = "Alias for data_platform_folder_id consumed by enterprise data stage 01."
}

output "environment_folder_ids" {
  value       = module.folder_hierarchy.environment_folder_ids
  description = "Map of environment names to fldr-environments/fldr-<env> folder resource names."
}

output "environment_data_platform_folder_ids" {
  value       = module.folder_hierarchy.environment_data_platform_folder_ids
  description = "Map of environment names to per-environment fldr-<env>-data-platform folder resource names."
}

output "environment_storage_folder_ids" {
  value       = module.folder_hierarchy.environment_storage_folder_ids
  description = "Map of environment names to per-environment storage folder resource names."
}

output "environment_compute_folder_ids" {
  value       = module.folder_hierarchy.environment_compute_folder_ids
  description = "Map of environment names to per-environment compute folder resource names."
}

output "environment_ai_folder_ids" {
  value       = module.folder_hierarchy.environment_ai_folder_ids
  description = "Map of environment names to per-environment ai folder resource names."
}

output "environment_app_folder_ids" {
  value       = module.folder_hierarchy.environment_app_folder_ids
  description = "Map of environment names to per-environment app folder resource names."
}

output "environment_network_folder_ids" {
  value       = module.folder_hierarchy.environment_network_folder_ids
  description = "Map of environment names to the top-level fldr-network folder resource name."
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
  description = "Central audit logging project ID (also hosts FinOps or SecOps when dedicated projects are disabled)."
}

output "audit_project_number" {
  value       = module.audit_project.project_number
  description = "Numeric audit project number for VPC-SC audit egress."
}

output "audit_project_lien_name" {
  value       = try(google_resource_manager_lien.audit_project[0].name, "")
  description = "Resource Manager deletion lien name on the audit project, or empty string."
}

output "audit_kms_key_id" {
  value       = try(google_kms_crypto_key.audit_cmek[0].id, null)
  description = "Stage-01 CMEK crypto key ID encrypting audit SCC and Pub/Sub resources, or null."
}

output "finops_project_id" {
  value       = local.effective_finops_project
  description = "Effective FinOps project ID hosting Cloud Billing export, budgets, and monitoring channels."
}

output "finops_project_number" {
  value       = var.create_dedicated_finops_project ? module.finops_project[0].project_number : module.audit_project.project_number
  description = "Numeric project number of the effective FinOps project."
}

output "secops_project_id" {
  value       = local.effective_secops_project
  description = "Effective SecOps project ID hosting SCC findings and alerting."
}

output "secops_project_number" {
  value       = var.create_dedicated_secops_project ? module.secops_project[0].project_number : module.audit_project.project_number
  description = "Numeric project number of the effective SecOps project."
}

output "golden_images_project_number" {
  value       = var.create_dedicated_secops_project ? module.secops_project[0].project_number : module.audit_project.project_number
  description = "Numeric project number hosting the shared golden Artifact Registry repository."
}

output "shared_artifact_registry_id" {
  value       = try(google_artifact_registry_repository.golden_images[0].id, "")
  description = "Shared golden Docker Artifact Registry repository resource ID, or empty string."
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

output "environment_budget_names" {
  value       = module.finops_governance.environment_budget_names
  description = "Map of environment names to Cloud Billing budget resource names."
}

output "workload_budget_names" {
  value       = module.finops_governance.workload_budget_names
  description = "Map of workload keys to Cloud Billing budget resource names."
}

output "department_budget_names" {
  value       = module.finops_governance.department_budget_names
  description = "Map of department cost_center keys to Cloud Billing budget resource names."
}

output "backup_project_id" {
  value       = var.enable_backup_dr ? module.backup_project[0].project_id : ""
  description = "Dedicated Backup and DR project ID when enabled, or empty string."
}

output "backup_project_number" {
  value       = var.enable_backup_dr ? module.backup_project[0].project_number : ""
  description = "Numeric project number of the Backup and DR project when enabled, or empty string."
}

output "backup_vault_id" {
  value       = try(module.backup_dr[0].backup_vault_id, null)
  description = "Backup and DR vault resource ID when enabled, or null."
}

output "gce_backup_plan_id" {
  value       = try(module.backup_dr[0].gce_backup_plan_id, null)
  description = "Daily Compute Engine Backup and DR plan ID when enabled, or null."
}

output "cloudsql_backup_plan_id" {
  value       = try(module.backup_dr[0].cloudsql_backup_plan_id, null)
  description = "Daily Cloud SQL Backup and DR plan ID when enabled, or null."
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

output "auto_unique_suffix" {
  value       = var.auto_unique_suffix
  description = "Automatic 4-hex uniqueness suffix toggle propagated to environment stages."
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

output "scc_tier" {
  value       = module.scc_secops.scc_tier
  description = "Effective Security Command Center tier (NONE, STANDARD, or PREMIUM)."
}

output "scc_scope" {
  value       = module.scc_secops.scc_scope
  description = "Configured Security Command Center scope (ORGANIZATION, FOLDER, or PROJECT)."
}

output "scc_custom_etd_module_id" {
  value       = module.scc_secops.scc_custom_etd_module_id
  description = "Organization Event Threat Detection custom module resource name, or null."
}

output "scc_findings_dataset_id" {
  value       = module.scc_secops.scc_findings_dataset_id
  description = "Regional BigQuery dataset ID storing exported SCC v2 findings, or null."
}

output "scc_big_query_export_name" {
  value       = module.scc_secops.scc_big_query_export_name
  description = "SCC v2 continuous BigQuery export resource name, or null."
}

output "scc_findings_topic_id" {
  value       = module.scc_secops.scc_findings_topic_id
  description = "Pub/Sub topic ID for HIGH and CRITICAL SCC v2 findings, or null."
}

output "scc_pubsub_topic_id" {
  value       = module.scc_secops.scc_findings_topic_id
  description = "Alias for scc_findings_topic_id for backwards compatibility."
}

output "scc_findings_subscription_id" {
  value       = module.scc_secops.scc_findings_subscription_id
  description = "Pub/Sub pull subscription ID monitored for unacknowledged SCC findings, or null."
}

output "scc_custom_sha_module_ids" {
  value       = module.scc_secops.scc_custom_sha_module_ids
  description = "Custom Security Health Analytics module resource names deployed in PREMIUM tier."
}

output "scc_posture_deployment_id" {
  value       = module.scc_secops.scc_posture_deployment_id
  description = "Security Posture deployment resource name on the root organization or folder, or null."
}

output "enforced_org_policy_names" {
  value       = module.logging_guardrails.enforced_org_policy_names
  description = "Sorted resource names of enforced folder Org Policies."
}

output "delete_contents_on_destroy" {
  value       = var.delete_contents_on_destroy
  description = "Destructive cleanup flag propagated downstream."
}
