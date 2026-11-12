output "kms_key_id" {
  value       = try(google_kms_crypto_key.this[0].id, null)
  description = "Resource ID of the regional CMEK crypto key, or null."
}

output "dr_kms_key_id" {
  value       = try(google_kms_crypto_key.dr[0].id, null)
  description = "Resource ID of the secondary DR CMEK crypto key, or null."
}

output "network_id" {
  value       = try(google_compute_network.this[0].id, null)
  description = "Resource ID of the custom VPC network, or null."
}

output "vpc_id" {
  value       = try(google_compute_network.this[0].id, null)
  description = "Alias of network_id for the custom VPC network, or null."
}

output "shared_vpc_host_project_id" {
  value       = try(google_compute_shared_vpc_host_project.this[0].project, "")
  description = "Shared VPC host project ID when enabled, or empty string."
}

output "subnet_id" {
  value       = try(google_compute_subnetwork.this[0].id, null)
  description = "Resource ID of the private subnetwork, or null."
}

output "datastream_network_attachment_id" {
  value       = try(google_compute_network_attachment.datastream[0].id, "")
  description = "Resource ID of the Datastream PSC network attachment, or empty string."
}

output "psc_address" {
  value       = try(google_compute_global_address.psc[0].address, null)
  description = "Reserved internal IP address for Private Service Connect, or null."
}

output "egress_firewall_policy_id" {
  value       = try(google_compute_network_firewall_policy.egress[0].id, null)
  description = "Resource ID of the PSC egress network firewall policy, or null."
}

output "vpc_sc_perimeter_name" {
  value       = try(google_access_context_manager_service_perimeter.perimeter[0].name, "")
  description = "Full resource name of the VPC-SC service perimeter, or empty string."
}

output "enforce_vpc_sc" {
  value       = var.enforce_vpc_sc
  description = "Whether the VPC-SC perimeter runs in enforced mode."
}

output "vpc_sc_access_level_name" {
  value       = try(google_access_context_manager_access_level.trusted[0].name, "")
  description = "Full resource name of the optional ACM access level, or empty string."
}
