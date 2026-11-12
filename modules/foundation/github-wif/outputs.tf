output "wif_pool_name" {
  value       = google_iam_workload_identity_pool.github.name
  description = "Full resource name of the GitHub Workload Identity Pool."
}

output "wif_pool_id" {
  value       = google_iam_workload_identity_pool.github.workload_identity_pool_id
  description = "Short ID of the GitHub Workload Identity Pool."
}

output "wif_provider_name" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Full resource name of the GitHub OIDC Workload Identity Pool Provider."
}

output "attribute_condition" {
  value       = google_iam_workload_identity_pool_provider.github.attribute_condition
  description = "Compiled CEL attribute condition enforced on GitHub OIDC tokens."
}
