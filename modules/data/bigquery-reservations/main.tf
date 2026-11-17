locals {
  effective_bi_project_id = var.bi_project_id != null ? trimspace(var.bi_project_id) : ""
  effective_assignments = merge(
    local.effective_bi_project_id != "" ? { (local.effective_bi_project_id) = "adhoc" } : {},
    var.assignments,
  )
  normalized_reservations = {
    for k, r in var.reservations :
    k => merge(r, {
      trimmed_secondary_location = r.secondary_location != null ? trimspace(r.secondary_location) : ""
    })
  }
}

resource "google_bigquery_reservation" "this" {
  for_each = local.normalized_reservations

  project            = var.project_id
  location           = var.region
  secondary_location = each.value.trimmed_secondary_location != "" ? each.value.trimmed_secondary_location : null
  name               = "${var.prefix}-${each.key}"
  edition            = each.value.edition
  slot_capacity      = each.value.slot_capacity
  ignore_idle_slots  = each.value.ignore_idle_slots
  labels             = var.labels

  dynamic "autoscale" {
    for_each = (each.value.max_slots != null ? each.value.max_slots : 0) > 0 ? [each.value.max_slots] : []
    content {
      max_slots = autoscale.value
    }
  }

  lifecycle {
    precondition {
      condition     = each.value.trimmed_secondary_location == "" || each.value.edition == "ENTERPRISE_PLUS"
      error_message = "secondary_location requires edition = \"ENTERPRISE_PLUS\" on BigQuery reservations."
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
