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
  description = "Resource name of the fldr-coe folder."
}

output "coe_folder_id" {
  value       = google_folder.shared_infra.name
  description = "Alias for shared_infra_folder_id (fldr-coe folder resource name)."
}

output "network_folder_id" {
  value       = google_folder.network.name
  description = "Resource name of the top-level fldr-network folder."
}

output "environment_folder_ids" {
  value       = { for k, f in google_folder.env : k => f.name }
  description = "Map of environment names to fldr-environments/fldr-<env> folder resource names."
}

output "environment_data_platform_folder_ids" {
  value       = { for k, f in google_folder.env_data_platform : k => f.name }
  description = "Map of environment names to fldr-environments/fldr-<env>/fldr-<env>-data-platform folder resource names."
}

output "environment_storage_folder_ids" {
  value       = var.create_data_subfolders ? { for k, f in google_folder.env_storage : k => f.name } : { for k, f in google_folder.env_data_platform : k => f.name }
  description = "Map of environment names to per-environment storage folder resource names (falling back to fldr-<env>-data-platform when create_data_subfolders is false)."
}

output "environment_compute_folder_ids" {
  value       = var.create_data_subfolders ? { for k, f in google_folder.env_compute : k => f.name } : { for k, f in google_folder.env_data_platform : k => f.name }
  description = "Map of environment names to per-environment compute folder resource names (falling back to fldr-<env>-data-platform when create_data_subfolders is false)."
}

output "environment_ai_folder_ids" {
  value       = { for k, f in google_folder.env_ai : k => f.name }
  description = "Map of environment names to per-environment fldr-<env>-ai-platform folder resource names."
}

output "environment_app_folder_ids" {
  value       = { for k, f in google_folder.env_app : k => f.name }
  description = "Map of environment names to per-environment fldr-<env>-app-platform folder resource names."
}

output "environment_network_folder_ids" {
  value       = { for k in local.environment_set : k => google_folder.network.name }
  description = "Map of environment names to the top-level fldr-network folder resource name."
}

output "storage_folder_id" {
  value       = local.default_env_key != "" ? (var.create_data_subfolders ? google_folder.env_storage[local.default_env_key].name : google_folder.env_data_platform[local.default_env_key].name) : null
  description = "Default storage folder resource name (prod or first environment) for backwards compatibility."
}

output "compute_folder_id" {
  value       = local.default_env_key != "" ? (var.create_data_subfolders ? google_folder.env_compute[local.default_env_key].name : google_folder.env_data_platform[local.default_env_key].name) : null
  description = "Default compute folder resource name (prod or first environment) for backwards compatibility."
}
