output "finops_project_id" {
  value       = local.effective_project_id
  description = "Effective GCP project ID hosting FinOps billing export, budgets, and alerts."
}

output "billing_export_dataset_id" {
  value       = google_bigquery_dataset.billing_export.dataset_id
  description = "BigQuery dataset ID reserved for Cloud Billing export."
}

output "budget_pubsub_topic_id" {
  value       = google_pubsub_topic.budget_alerts.id
  description = "Pub/Sub topic ID receiving Cloud Billing budget alerts."
}

output "budget_name" {
  value       = try(google_billing_budget.monthly[0].name, null)
  description = "Master Cloud Billing budget resource name, or null when disabled."
}

output "environment_budget_names" {
  value       = { for k, b in google_billing_budget.environment : k => b.name }
  description = "Map of environment names to Cloud Billing budget resource names."
}

output "workload_budget_names" {
  value       = { for k, b in google_billing_budget.workload : k => b.name }
  description = "Map of workload keys to Cloud Billing budget resource names."
}

output "department_budget_names" {
  value       = { for k, b in google_billing_budget.department : k => b.name }
  description = "Map of department cost_center keys to Cloud Billing budget resource names."
}

output "notification_channel_ids" {
  value       = { for email, ch in google_monitoring_notification_channel.budget_email : email => ch.name }
  description = "Map of FinOps email addresses to Cloud Monitoring notification channel names."
}

output "finops_tag_value_ids" {
  value       = { for k, v in google_tags_tag_value.finops : k => v.id }
  description = "Map of cost-allocation tag keys and values to Resource Manager tag value IDs."
}
