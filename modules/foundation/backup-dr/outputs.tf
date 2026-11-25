output "backup_vault_id" {
  value       = google_backup_dr_backup_vault.primary.id
  description = "Full resource ID of the Backup and DR vault."
}

output "backup_vault_name" {
  value       = google_backup_dr_backup_vault.primary.name
  description = "Resource name of the Backup and DR vault."
}

output "backup_vault_service_account" {
  value       = google_backup_dr_backup_vault.primary.service_account
  description = "Service account identity used by the Backup and DR vault."
}

output "gce_backup_plan_id" {
  value       = try(google_backup_dr_backup_plan.gce[0].id, null)
  description = "Resource ID of the daily Compute Engine backup plan, or null."
}

output "cloudsql_backup_plan_id" {
  value       = try(google_backup_dr_backup_plan.cloudsql[0].id, null)
  description = "Resource ID of the daily Cloud SQL backup plan, or null."
}
