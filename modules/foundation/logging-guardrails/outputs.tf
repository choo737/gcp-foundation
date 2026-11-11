output "log_bucket_id" {
  value       = google_logging_project_bucket_config.audit.id
  description = "Resource ID of the audit Cloud Logging bucket."
}

output "log_sink_writer_identity" {
  value       = try(google_logging_folder_sink.audit[0].writer_identity, null)
  description = "Writer service account identity of the folder audit sink."
}
