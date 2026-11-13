output "scc_tier" {
  value       = var.scc_tier
  description = "Active Security Command Center tier (NONE, STANDARD, or PREMIUM)."
}

output "scc_findings_dataset_id" {
  value       = try(google_bigquery_dataset.scc_findings[0].dataset_id, null)
  description = "Regional BigQuery dataset ID storing exported SCC v2 findings, or null."
}

output "scc_big_query_export_name" {
  value       = try(google_scc_v2_folder_scc_big_query_export.active_findings[0].name, null)
  description = "SCC v2 continuous BigQuery export resource name, or null."
}

output "scc_findings_topic_id" {
  value       = try(google_pubsub_topic.scc_findings[0].id, null)
  description = "Pub/Sub topic ID for HIGH and CRITICAL SCC v2 findings, or null."
}

output "scc_findings_subscription_id" {
  value       = try(google_pubsub_subscription.scc_findings_alert[0].id, null)
  description = "Pub/Sub pull subscription ID monitored for unacknowledged SCC findings, or null."
}

output "scc_alert_policy_name" {
  value       = try(google_monitoring_alert_policy.scc_unacked_findings[0].name, null)
  description = "Cloud Monitoring alert policy resource name for SCC findings, or null."
}

output "scc_mute_config_ids" {
  value       = { for env, cfg in google_scc_v2_folder_mute_config.nonprod : env => cfg.name }
  description = "Map of non-production environment keys to SCC v2 mute config resource names."
}

output "scc_custom_sha_module_ids" {
  value = compact([
    try(google_scc_management_folder_security_health_analytics_custom_module.prod_bq_cmek[0].name, ""),
    try(google_scc_management_folder_security_health_analytics_custom_module.gcs_ubla[0].name, ""),
  ])
  description = "Custom Security Health Analytics module resource names deployed in PREMIUM tier."
}

output "scc_posture_id" {
  value       = try(google_securityposture_posture.foundation[0].name, null)
  description = "Declarative Security Posture resource name, or null."
}

output "scc_posture_deployment_id" {
  value       = try(google_securityposture_posture_deployment.root_folder[0].name, null)
  description = "Security Posture deployment resource name on the root folder, or null."
}
