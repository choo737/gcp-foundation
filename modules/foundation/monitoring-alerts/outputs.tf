output "notification_channel_ids" {
  value       = local.notification_channel_ids
  description = "List of Cloud Monitoring notification channel resource names."
}

output "alert_policy_ids" {
  value = compact([
    try(google_monitoring_alert_policy.pubsub_dlq_backlog[0].id, ""),
    try(google_monitoring_alert_policy.workflows_failed[0].id, ""),
    try(google_monitoring_alert_policy.cloud_run_job_failed[0].id, ""),
    try(google_monitoring_alert_policy.bigquery_slot_saturation[0].id, ""),
    try(google_monitoring_alert_policy.dataform_failures[0].id, ""),
  ])
  description = "List of Cloud Monitoring alert policy resource IDs."
}

output "dataform_log_metric_name" {
  value       = try(google_logging_metric.dataform_failures[0].name, "")
  description = "Cloud Logging metric name tracking Dataform workflow errors."
}
