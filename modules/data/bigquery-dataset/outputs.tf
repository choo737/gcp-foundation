output "dataset_id" {
  value       = google_bigquery_dataset.this.dataset_id
  description = "BigQuery dataset ID."
}

output "project_id" {
  value       = google_bigquery_dataset.this.project
  description = "Project ID hosting the dataset."
}

output "self_link" {
  value       = google_bigquery_dataset.this.self_link
  description = "Self link URI of the dataset."
}
