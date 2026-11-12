output "network_project_id" {
  value       = module.network_project.project_id
  description = "Network and security foundation project ID."
}

output "kms_key_id" {
  value       = module.network_security.kms_key_id
  description = "Regional CMEK crypto key resource ID."
}

output "network_id" {
  value       = module.network_security.network_id
  description = "Custom VPC network resource ID, or null."
}

output "vpc_id" {
  value       = module.network_security.vpc_id
  description = "Custom VPC network resource ID exported for downstream ingestion stages, or null."
}

output "subnet_id" {
  value       = module.network_security.subnet_id
  description = "Private subnetwork resource ID, or null."
}

output "psc_address" {
  value       = module.network_security.psc_address
  description = "Private Service Connect internal IP address, or null."
}

output "egress_firewall_policy_id" {
  value       = module.network_security.egress_firewall_policy_id
  description = "PSC egress network firewall policy ID, or null."
}
