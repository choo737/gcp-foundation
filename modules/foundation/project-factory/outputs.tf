output "project_id" {
  value       = google_project.this.project_id
  description = "Created GCP project ID."
}

output "project_number" {
  value       = google_project.this.number
  description = "Numeric GCP project number."
}

output "service_account_emails" {
  value       = { for k, sa in google_service_account.this : k => sa.email }
  description = "Map of service account keys to created email addresses."
}
