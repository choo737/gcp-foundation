output "network_project_id" {
  value       = module.network_project.project_id
  description = "Network and security foundation project ID."
}

output "network_project_number" {
  value       = module.network_project.project_number
  description = "Numeric project number of the network security project."
}

output "shared_vpc_host_project_id" {
  value       = module.network_security.shared_vpc_host_project_id
  description = "Shared VPC host project ID when enabled, or empty string."
}

output "kms_key_id" {
  value       = module.network_security.kms_key_id
  description = "Regional CMEK crypto key resource ID."
}

output "dr_kms_key_id" {
  value       = module.network_security.dr_kms_key_id
  description = "Secondary DR CMEK crypto key resource ID, or null."
}

output "network_id" {
  value       = module.network_security.network_id
  description = "Custom VPC network resource ID, or null."
}

output "vpc_id" {
  value       = module.network_security.vpc_id
  description = "Custom VPC network resource ID exported for downstream ingestion stages, or null."
}

output "subnet_id" {
  value       = module.network_security.subnet_id
  description = "Private subnetwork resource ID, or null."
}

output "department_subnet_ids" {
  value       = module.network_security.department_subnet_ids
  description = "Map of department keys (data, ai, app) to dedicated subnetwork resource IDs."
}

output "department_subnet_secondary_range_names" {
  value       = module.network_security.department_subnet_secondary_range_names
  description = "Map of department keys to GKE secondary IP range names (pods and services)."
}

output "data_subnet_id" {
  value       = module.network_security.data_subnet_id
  description = "Data department subnetwork resource ID, falling back to subnet_id."
}

output "ai_subnet_id" {
  value       = module.network_security.ai_subnet_id
  description = "AI department subnetwork resource ID, falling back to subnet_id."
}

output "app_subnet_id" {
  value       = module.network_security.app_subnet_id
  description = "Application department subnetwork resource ID, falling back to subnet_id."
}

output "datastream_network_attachment_id" {
  value       = module.network_security.datastream_network_attachment_id
  description = "Datastream PSC network attachment ID, or empty string."
}

output "psc_address" {
  value       = module.network_security.psc_address
  description = "Private Service Connect internal IP address, or null."
}

output "egress_firewall_policy_id" {
  value       = module.network_security.egress_firewall_policy_id
  description = "PSC egress network firewall policy ID, or null."
}

output "hierarchical_firewall_policy_id" {
  value       = module.network_security.hierarchical_firewall_policy_id
  description = "Folder-level hierarchical firewall policy ID, or null."
}

output "secure_tag_key_ids" {
  value       = module.network_security.secure_tag_key_ids
  description = "Map of GCE_FIREWALL secure tag key IDs (tier and access)."
}

output "secure_tag_value_ids" {
  value       = module.network_security.secure_tag_value_ids
  description = "Map of GCE_FIREWALL secure tag value IDs (web, app, data, allow_iap)."
}

output "ngfw_enterprise_endpoint_ids" {
  value       = module.network_security.ngfw_enterprise_endpoint_ids
  description = "Map of zones to NGFW Enterprise firewall endpoint IDs."
}

output "ngfw_security_profile_group_id" {
  value       = module.network_security.ngfw_security_profile_group_id
  description = "NGFW Enterprise security profile group ID, or null."
}

output "vpc_sc_perimeter_name" {
  value       = module.network_security.vpc_sc_perimeter_name
  description = "Full resource name of the VPC-SC service perimeter, or empty string."
}

output "enforce_vpc_sc" {
  value       = module.network_security.enforce_vpc_sc
  description = "Whether the VPC-SC perimeter runs in enforced mode."
}

output "vpc_sc_access_level_name" {
  value       = module.network_security.vpc_sc_access_level_name
  description = "Full resource name of the optional ACM access level, or empty string."
}

output "notification_channel_ids" {
  value       = module.monitoring_alerts.notification_channel_ids
  description = "Cloud Monitoring notification channel resource names."
}

output "alert_policy_ids" {
  value       = module.monitoring_alerts.alert_policy_ids
  description = "Cloud Monitoring alert policy resource IDs."
}

output "environment" {
  value       = var.environment
  description = "Lifecycle environment propagated downstream."
}

output "region" {
  value       = var.region
  description = "Default GCP region propagated downstream."
}

output "dr_region" {
  value       = var.dr_region
  description = "Optional disaster recovery region propagated downstream."
}

output "prefix" {
  value       = var.prefix
  description = "Naming prefix propagated downstream."
}

output "project_suffix" {
  value       = local.effective_project_suffix
  description = "Effective project uniqueness suffix propagated downstream."
}

output "auto_unique_suffix" {
  value       = var.auto_unique_suffix
  description = "Auto-unique suffix toggle propagated downstream."
}

output "project_deletion_policy" {
  value       = var.project_deletion_policy
  description = "Project deletion policy propagated downstream."
}

output "finops_tag_value_ids" {
  value       = var.finops_tag_value_ids
  description = "FinOps tag value IDs propagated downstream."
}

output "backup_project_id" {
  value       = var.backup_project_id
  description = "Optional Backup and DR project ID propagated downstream."
}

output "backup_vault_id" {
  value       = var.backup_vault_id
  description = "Optional Backup and DR vault ID propagated downstream."
}
