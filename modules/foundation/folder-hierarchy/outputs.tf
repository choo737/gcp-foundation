output "parent_id" {
  value       = var.parent_id
  description = "Parent organization or folder resource name."
}

output "root_folder_id" {
  value       = var.parent_id
  description = "Backwards-compatible alias for parent_id."
}

output "shared_infra_folder_id" {
  value       = google_folder.shared_infra.name
  description = "Resource name of the shared-infrastructure folder."
}

output "environment_folder_ids" {
  value       = { for k, f in google_folder.env : k => f.name }
  description = "Map of environment names to environments/<env> folder resource names."
}

output "environment_data_platform_folder_ids" {
  value       = { for k, f in google_folder.env_data_platform : k => f.name }
  description = "Map of environment names to environments/<env>/data-platform folder resource names."
}

output "environment_storage_folder_ids" {
  value       = { for k, f in google_folder.env_storage : k => f.name }
  description = "Map of environment names to per-environment storage folder resource names."
}

output "environment_compute_folder_ids" {
  value       = { for k, f in google_folder.env_compute : k => f.name }
  description = "Map of environment names to per-environment compute folder resource names."
}

output "environment_ai_folder_ids" {
  value       = { for k, f in google_folder.env_ai : k => f.name }
  description = "Map of environment names to per-environment ai folder resource names."
}

output "environment_app_folder_ids" {
  value       = { for k, f in google_folder.env_app : k => f.name }
  description = "Map of environment names to per-environment app folder resource names."
}

output "environment_network_folder_ids" {
  value       = { for k, f in google_folder.env_network : k => f.name }
  description = "Map of environment names to per-environment network folder resource names."
}

output "storage_folder_id" {
  value       = local.default_env_key != "" ? google_folder.env_storage[local.default_env_key].name : null
  description = "Default storage folder resource name (prod or first environment) for backwards compatibility."
}

output "compute_folder_id" {
  value       = local.default_env_key != "" ? google_folder.env_compute[local.default_env_key].name : null
  description = "Default compute folder resource name (prod or first environment) for backwards compatibility."
}
