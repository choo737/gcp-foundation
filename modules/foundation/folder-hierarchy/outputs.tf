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
