locals {
  numeric_folder_id  = replace(var.folder_id, "folders/", "")
  folder_resource    = "folders/${local.numeric_folder_id}"
  effective_location = coalesce(var.logging_location, var.region)
}

resource "google_logging_project_bucket_config" "audit" {
  project        = var.audit_project_id
  location       = local.effective_location
  bucket_id      = "${var.prefix}-audit-logs"
  retention_days = var.retention_days
  locked         = var.lock_audit_bucket
  description    = "Centralized folder audit log bucket."
}

resource "google_logging_folder_sink" "audit" {
  count = var.enable_folder_sink ? 1 : 0

  name             = "${var.prefix}-folder-audit-sink"
  folder           = local.numeric_folder_id
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.audit.name}"
  include_children = true
  filter           = "logName:\"logs/cloudaudit.googleapis.com\""
}

resource "google_project_iam_member" "log_sink_writer" {
  count = var.enable_folder_sink ? 1 : 0

  project = var.audit_project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_folder_sink.audit[0].writer_identity
}

resource "google_folder_iam_audit_config" "data_access" {
  for_each = var.enable_data_access_audit_logs ? var.data_access_audit_services : toset([])

  folder  = local.folder_resource
  service = each.value

  audit_log_config {
    log_type = "ADMIN_READ"
  }

  audit_log_config {
    log_type = "DATA_READ"
  }

  audit_log_config {
    log_type = "DATA_WRITE"
  }
}

resource "google_org_policy_policy" "boolean_guardrails" {
  for_each = var.enable_org_policies ? var.boolean_org_policies : toset([])

  name   = "${local.folder_resource}/policies/${each.value}"
  parent = local.folder_resource

  spec {
    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "deny_all_guardrails" {
  for_each = var.enable_org_policies ? var.deny_all_org_policies : toset([])

  name   = "${local.folder_resource}/policies/${each.value}"
  parent = local.folder_resource

  spec {
    rules {
      deny_all = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  count = var.enable_org_policies && length(var.allowed_resource_locations) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/gcp.resourceLocations"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = var.allowed_resource_locations
      }
    }
  }
}
