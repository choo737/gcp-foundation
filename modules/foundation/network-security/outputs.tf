output "kms_key_id" {
  value       = try(google_kms_crypto_key.this[0].id, null)
  description = "Resource ID of the regional CMEK crypto key, or null."
}

output "network_id" {
  value       = try(google_compute_network.this[0].id, null)
  description = "Resource ID of the custom VPC network, or null."
}

output "vpc_id" {
  value       = try(google_compute_network.this[0].id, null)
  description = "Alias of network_id for the custom VPC network, or null."
}

output "subnet_id" {
  value       = try(google_compute_subnetwork.this[0].id, null)
  description = "Resource ID of the private subnetwork, or null."
}

output "psc_address" {
  value       = try(google_compute_global_address.psc[0].address, null)
  description = "Reserved internal IP address for Private Service Connect, or null."
}

output "egress_firewall_policy_id" {
  value       = try(google_compute_network_firewall_policy.egress[0].id, null)
  description = "Resource ID of the PSC egress network firewall policy, or null."
}
