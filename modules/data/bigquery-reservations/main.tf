locals {
  effective_bi_project_id = var.bi_project_id != null ? trimspace(var.bi_project_id) : ""
  effective_assignments = merge(
    local.effective_bi_project_id != "" ? { (local.effective_bi_project_id) = "adhoc" } : {},
    var.assignments,
  )
}

resource "google_bigquery_reservation" "this" {
  for_each = var.reservations

  project           = var.project_id
  location          = var.region
  name              = "${var.prefix}-${each.key}"
  edition           = each.value.edition
  slot_capacity     = each.value.slot_capacity
  ignore_idle_slots = each.value.ignore_idle_slots
  labels            = var.labels

  dynamic "autoscale" {
    for_each = (each.value.max_slots != null ? each.value.max_slots : 0) > 0 ? [each.value.max_slots] : []
    content {
      max_slots = autoscale.value
    }
  }
}

resource "google_bigquery_reservation_assignment" "this" {
  for_each = local.effective_assignments

  project     = var.project_id
  location    = var.region
  assignee    = "projects/${each.key}"
  job_type    = "QUERY"
  reservation = google_bigquery_reservation.this[each.value].id
}
