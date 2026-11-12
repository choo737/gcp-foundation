output "log_bucket_id" {
  value       = google_logging_project_bucket_config.audit.id
  description = "Resource ID of the audit Cloud Logging bucket."
}

output "log_analytics_linked_dataset_id" {
  value       = try(google_logging_linked_dataset.audit[0].bigquery_dataset[0].dataset_id, null)
  description = "BigQuery linked dataset ID for Cloud Logging Log Analytics, or null."
}

output "log_sink_writer_identity" {
  value       = try(google_logging_folder_sink.audit[0].writer_identity, null)
  description = "Writer service account identity of the folder audit sink."
}

output "siem_pubsub_topic_id" {
  value       = try(google_pubsub_topic.siem_logs[0].id, null)
  description = "Pub/Sub topic ID for optional SIEM log export, or null."
}

output "scc_pubsub_topic_id" {
  value       = try(google_pubsub_topic.scc_findings[0].id, null)
  description = "Pub/Sub topic ID for SCC v2 high and critical findings, or null."
}

output "enforced_org_policy_names" {
  value = sort(concat(
    values(google_org_policy_policy.boolean_guardrails)[*].name,
    values(google_org_policy_policy.deny_all_guardrails)[*].name,
    google_org_policy_policy.resource_locations[*].name,
    google_org_policy_policy.policy_member_domains[*].name,
    google_org_policy_policy.contact_domains[*].name,
    google_org_policy_policy.storage_auth_types[*].name,
    google_org_policy_policy.cloud_run_ingress[*].name,
    google_org_policy_policy.cloud_functions_ingress[*].name,
    google_org_policy_policy.protocol_forwarding[*].name,
  ))
  description = "Sorted resource names of all enforced folder Org Policies."
}
