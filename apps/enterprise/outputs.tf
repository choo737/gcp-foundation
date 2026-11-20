output "app_folder_ids" {
  value       = module.workload_factory.app_folder_ids
  description = "Map of application keys to per-application folder resource names."
}

output "app_project_ids" {
  value       = module.workload_factory.app_project_ids
  description = "Map of application keys to provisioned GCP project IDs."
}

output "app_project_numbers" {
  value       = module.workload_factory.app_project_numbers
  description = "Map of application keys to numeric GCP project numbers."
}

output "app_runtime_sa_emails" {
  value       = module.workload_factory.app_runtime_sa_emails
  description = "Map of application keys to dedicated least-privilege runtime service account emails."
}

output "effective_app_folder_id" {
  value       = local.effective_app_folder_id
  description = "Resolved parent application folder resource name."
}

output "environment" {
  value       = var.environment
  description = "Lifecycle environment propagated downstream."
}

output "region" {
  value       = var.region
  description = "GCP region propagated downstream."
}

output "prefix" {
  value       = var.prefix
  description = "Naming prefix propagated downstream."
}

output "vpc_id" {
  value       = var.vpc_id
  description = "Shared VPC network resource ID propagated to application workloads."
}

output "subnet_id" {
  value       = var.subnet_id
  description = "Shared VPC application subnetwork ID propagated to application workloads."
}
