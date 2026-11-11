output "reservation_ids" {
  value       = { for k, r in google_bigquery_reservation.this : k => r.id }
  description = "Map of reservation keys to BigQuery reservation resource IDs."
}

output "assignment_ids" {
  value       = { for k, a in google_bigquery_reservation_assignment.this : k => a.id }
  description = "Map of assignee project IDs to reservation assignment IDs."
}
