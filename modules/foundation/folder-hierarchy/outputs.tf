output "root_folder_id" {
  value       = try(google_folder.root[0].name, var.parent_id)
  description = "Resource name of the root folder (folders/<id> or parent_id)."
}

output "shared_infra_folder_id" {
  value       = google_folder.shared_infra.name
  description = "Resource name of the 01-shared-infrastructure folder."
}

output "workloads_folder_id" {
  value       = google_folder.workloads.name
  description = "Resource name of the 02-workloads folder."
}

output "workload_folder_ids" {
  value       = { for k, f in google_folder.workload : k => f.name }
  description = "Map of workload pillar names to folder resource names."
}

output "environment_folder_ids" {
  value       = { for k, f in google_folder.env : k => f.name }
  description = "Map of environment names to 02-environments/<env> folder resource names."
}

output "environment_data_platform_folder_ids" {
  value       = { for k, f in google_folder.env_data_platform : k => f.name }
  description = "Map of environment names to 02-environments/<env>/data-platform folder resource names."
}

output "environment_storage_folder_ids" {
  value       = { for k, f in google_folder.env_storage : k => f.name }
  description = "Map of environment names to per-environment storage folder resource names."
}

output "environment_compute_folder_ids" {
  value       = { for k, f in google_folder.env_compute : k => f.name }
  description = "Map of environment names to per-environment compute folder resource names."
}

output "storage_folder_id" {
  value       = local.default_env_key != "" ? google_folder.env_storage[local.default_env_key].name : null
  description = "Default storage folder resource name (prod or first environment) for backwards compatibility."
}

output "compute_folder_id" {
  value       = local.default_env_key != "" ? google_folder.env_compute[local.default_env_key].name : null
  description = "Default compute folder resource name (prod or first environment) for backwards compatibility."
}
