output "log_bucket_id" {
  value       = google_logging_project_bucket_config.audit.id
  description = "Resource ID of the audit Cloud Logging bucket."
}

output "log_sink_writer_identity" {
  value       = try(google_logging_folder_sink.audit[0].writer_identity, null)
  description = "Writer service account identity of the folder audit sink."
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
  ))
  description = "Sorted resource names of all enforced folder Org Policies."
}
