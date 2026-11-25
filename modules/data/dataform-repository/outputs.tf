output "repository_name" {
  value       = google_dataform_repository.this.name
  description = "Dataform repository short name."
}

output "release_config_name" {
  value       = try(google_dataform_repository_release_config.prod[0].name, "")
  description = "Dataform release configuration name, or empty string when unlinked."
}

output "workflow_config_name" {
  value       = try(google_dataform_repository_workflow_config.scheduled[0].name, "")
  description = "Dataform workflow configuration name, or empty string when disabled."
}

output "service_account_email" {
  value       = local.effective_sa_email
  description = "Service account email configured on the Dataform repository."
}
