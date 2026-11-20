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

output "department_subnet_ids" {
  value       = { for k, s in google_compute_subnetwork.department : k => s.id }
  description = "Map of department keys (data, ai, app) to dedicated subnetwork resource IDs."
}

output "department_subnet_secondary_range_names" {
  value = {
    for k, cfg in local.department_secondary_ranges :
    k => {
      pods     = cfg.pods.range_name
      services = cfg.services.range_name
    }
  }
  description = "Map of department keys to GKE secondary IP range names (pods and services)."
}

output "data_subnet_id" {
  value       = try(google_compute_subnetwork.department["data"].id, try(google_compute_subnetwork.this[0].id, null))
  description = "Data department subnetwork resource ID, falling back to primary subnet_id."
}

output "ai_subnet_id" {
  value       = try(google_compute_subnetwork.department["ai"].id, try(google_compute_subnetwork.this[0].id, null))
  description = "AI department subnetwork resource ID, falling back to primary subnet_id."
}

output "app_subnet_id" {
  value       = try(google_compute_subnetwork.department["app"].id, try(google_compute_subnetwork.this[0].id, null))
  description = "Application department subnetwork resource ID, falling back to primary subnet_id."
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

output "hierarchical_firewall_policy_id" {
  value       = try(google_compute_firewall_policy.folder[0].id, null)
  description = "Resource ID of the folder-level hierarchical firewall policy, or null."
}

output "secure_tag_key_ids" {
  value = {
    tier   = try(google_tags_tag_key.tier[0].id, null)
    access = try(google_tags_tag_key.access[0].id, null)
  }
  description = "Map of GCE_FIREWALL secure tag key IDs (tier and access)."
}

output "secure_tag_value_ids" {
  value = merge(
    { for k, v in google_tags_tag_value.tier : k => v.id },
    length(google_tags_tag_value.allow_iap) > 0 ? { allow_iap = google_tags_tag_value.allow_iap[0].id } : {},
  )
  description = "Map of GCE_FIREWALL secure tag value IDs (web, app, data, allow_iap)."
}

output "ngfw_enterprise_endpoint_ids" {
  value       = { for k, v in google_network_security_firewall_endpoint.ngfw : k => v.id }
  description = "Map of zones to NGFW Enterprise firewall endpoint IDs."
}

output "ngfw_security_profile_group_id" {
  value       = try(google_network_security_security_profile_group.ngfw[0].id, null)
  description = "NGFW Enterprise security profile group ID, or null."
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
