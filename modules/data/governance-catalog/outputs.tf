output "taxonomy_id" {
  value       = google_data_catalog_taxonomy.pii.id
  description = "Full resource ID of the PII Data Catalog taxonomy."
}

output "pii_restricted_policy_tag_id" {
  value       = google_data_catalog_policy_tag.pii_restricted.name
  description = "Resource name of the restricted PII policy tag."
}

output "pii_masked_policy_tag_id" {
  value       = google_data_catalog_policy_tag.pii_masked.name
  description = "Resource name of the masked PII policy tag."
}

output "pii_data_policy_id" {
  value       = google_bigquery_datapolicy_data_policy.pii_mask.id
  description = "Full resource ID of the BigQuery PII data masking policy."
}

output "pii_data_policy_short_id" {
  value       = google_bigquery_datapolicy_data_policy.pii_mask.data_policy_id
  description = "Short data_policy_id of the BigQuery PII data masking policy."
}

output "glossary_id" {
  value       = try(google_dataplex_glossary.business[0].id, null)
  description = "Resource ID of the Dataplex business glossary, or null."
}
