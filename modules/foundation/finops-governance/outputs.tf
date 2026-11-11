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
  description = "Cloud Billing budget resource name, or null when disabled."
}

output "finops_tag_value_ids" {
  value       = { for k, v in google_tags_tag_value.finops : k => v.id }
  description = "Map of cost-allocation tag keys and values to Resource Manager tag value IDs."
}
