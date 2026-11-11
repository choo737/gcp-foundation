output "scan_names" {
  value       = { for k, s in google_dataplex_datascan.profile : k => s.name }
  description = "Map of profile table keys to full Dataplex scan resource names."
}

output "scan_ids" {
  value       = { for k, s in google_dataplex_datascan.profile : k => s.data_scan_id }
  description = "Map of profile table keys to Dataplex data scan IDs."
}
