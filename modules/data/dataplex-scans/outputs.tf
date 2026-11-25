output "scan_names" {
  value       = { for k, s in google_dataplex_datascan.profile : k => s.name }
  description = "Map of profile table keys to full Knowledge Catalog scan resource names."
}

output "scan_ids" {
  value       = { for k, s in google_dataplex_datascan.profile : k => s.data_scan_id }
  description = "Map of profile table keys to Knowledge Catalog data scan IDs."
}

output "quality_scan_id" {
  value       = try(google_dataplex_datascan.quality[0].data_scan_id, google_dataplex_datascan.custom_quality[0].data_scan_id, "")
  description = "Knowledge Catalog data quality scan ID for Silver orders or custom rules, or empty string."
}

output "dataplex_quality_scan_id" {
  value       = try(google_dataplex_datascan.quality[0].data_scan_id, google_dataplex_datascan.custom_quality[0].data_scan_id, "")
  description = "Alias of quality_scan_id for downstream stage linking."
}

output "quality_scan_name" {
  value       = try(google_dataplex_datascan.quality[0].name, google_dataplex_datascan.custom_quality[0].name, "")
  description = "Full resource name of the Knowledge Catalog data quality scan, or empty string."
}
