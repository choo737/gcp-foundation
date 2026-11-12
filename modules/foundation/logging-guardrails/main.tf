locals {
  numeric_folder_id  = replace(var.folder_id, "folders/", "")
  folder_resource    = "folders/${local.numeric_folder_id}"
  effective_location = coalesce(var.logging_location, var.region)

  normalized_policy_member_domains = [
    for d in var.allowed_policy_member_domains :
    startswith(trimspace(d), "is:") ? trimspace(d) : "is:${trimspace(d)}"
    if trimspace(d) != ""
  ]

  normalized_contact_domains = [
    for d in var.allowed_contact_domains :
    startswith(trimspace(d), "@") ? trimspace(d) : "@${trimspace(d)}"
    if trimspace(d) != ""
  ]

  normalized_iam_groups = {
    for k, v in var.foundation_iam_groups :
    k => (
      startswith(trimspace(v), "group:") || startswith(trimspace(v), "user:") || startswith(trimspace(v), "serviceAccount:")
      ? trimspace(v)
      : "group:${trimspace(v)}"
    )
    if trimspace(v) != ""
  }

  folder_viewer_iam = {
    for k, role in {
      security_reviewer = "roles/iam.securityReviewer"
      network_viewer    = "roles/compute.networkViewer"
    } :
    k => {
      role   = role
      member = local.normalized_iam_groups[k]
    }
    if contains(keys(local.normalized_iam_groups), k)
  }
}

resource "google_logging_project_bucket_config" "audit" {
  project          = var.audit_project_id
  location         = local.effective_location
  bucket_id        = "${var.prefix}-audit-logs"
  retention_days   = var.retention_days
  locked           = var.lock_audit_bucket
  enable_analytics = var.enable_log_analytics
  description      = "Centralized folder audit log bucket."
}

resource "google_logging_linked_dataset" "audit" {
  count = var.enable_log_analytics && var.enable_log_analytics_link ? 1 : 0

  link_id     = "${replace(var.prefix, "-", "_")}_audit_logs"
  bucket      = google_logging_project_bucket_config.audit.id
  parent      = "projects/${var.audit_project_id}"
  location    = local.effective_location
  description = "BigQuery Log Analytics linked dataset for folder audit logs."
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

resource "google_org_policy_policy" "policy_member_domains" {
  count = var.enable_org_policies && length(local.normalized_policy_member_domains) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/iam.allowedPolicyMemberDomains"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = local.normalized_policy_member_domains
      }
    }
  }
}

resource "google_org_policy_policy" "contact_domains" {
  count = var.enable_org_policies && length(local.normalized_contact_domains) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/essentialcontacts.allowedContactDomains"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = local.normalized_contact_domains
      }
    }
  }
}

resource "google_org_policy_policy" "storage_auth_types" {
  count = var.enable_org_policies && length(var.denied_storage_auth_types) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/storage.restrictAuthTypes"
  parent = local.folder_resource

  spec {
    rules {
      values {
        denied_values = var.denied_storage_auth_types
      }
    }
  }
}

resource "google_org_policy_policy" "cloud_run_ingress" {
  count = var.enable_org_policies && length(var.allowed_cloud_run_ingress) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/run.allowedIngress"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = var.allowed_cloud_run_ingress
      }
    }
  }
}

resource "google_org_policy_policy" "cloud_functions_ingress" {
  count = var.enable_org_policies && length(var.allowed_cloud_functions_ingress) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/cloudfunctions.allowedIngressSettings"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = var.allowed_cloud_functions_ingress
      }
    }
  }
}

resource "google_org_policy_policy" "protocol_forwarding" {
  count = var.enable_org_policies && length(var.allowed_protocol_forwarding_types) > 0 ? 1 : 0

  name   = "${local.folder_resource}/policies/compute.restrictProtocolForwardingCreationForTypes"
  parent = local.folder_resource

  spec {
    rules {
      values {
        allowed_values = var.allowed_protocol_forwarding_types
      }
    }
  }
}

resource "google_pubsub_topic" "siem_logs" {
  count = var.enable_siem_pubsub_sink ? 1 : 0

  project = var.audit_project_id
  name    = "${var.prefix}-siem-audit-logs"
  labels  = var.labels
}

resource "google_logging_folder_sink" "siem" {
  count = var.enable_siem_pubsub_sink ? 1 : 0

  name             = "${var.prefix}-siem-folder-sink"
  folder           = local.numeric_folder_id
  destination      = "pubsub.googleapis.com/${google_pubsub_topic.siem_logs[0].id}"
  include_children = true
  filter           = "logName:\"logs/cloudaudit.googleapis.com\""
}

resource "google_pubsub_topic_iam_member" "siem_sink_writer" {
  count = var.enable_siem_pubsub_sink ? 1 : 0

  project = var.audit_project_id
  topic   = google_pubsub_topic.siem_logs[0].name
  role    = "roles/pubsub.publisher"
  member  = google_logging_folder_sink.siem[0].writer_identity
}

resource "google_pubsub_topic" "scc_findings" {
  count = var.enable_scc_notifications ? 1 : 0

  project = var.audit_project_id
  name    = "${var.prefix}-scc-findings"
  labels  = var.labels
}

resource "google_scc_v2_folder_notification_config" "high_critical" {
  count = var.enable_scc_notifications ? 1 : 0

  config_id    = "${var.prefix}-scc-high-crit"
  folder       = local.numeric_folder_id
  location     = var.scc_notification_location
  description  = "Stream HIGH and CRITICAL Security Command Center findings to Pub/Sub."
  pubsub_topic = google_pubsub_topic.scc_findings[0].id

  streaming_config {
    filter = "severity=\"HIGH\" OR severity=\"CRITICAL\""
  }
}

resource "google_essential_contacts_contact" "this" {
  for_each = var.essential_contacts

  parent                              = local.folder_resource
  email                               = each.value.email
  language_tag                        = each.value.language_tag
  notification_category_subscriptions = each.value.categories
}

resource "google_project_iam_member" "audit_viewer" {
  count = contains(keys(local.normalized_iam_groups), "audit_viewer") ? 1 : 0

  project = var.audit_project_id
  role    = "roles/logging.privateLogViewer"
  member  = local.normalized_iam_groups["audit_viewer"]
}

resource "google_folder_iam_member" "foundation_viewers" {
  for_each = local.folder_viewer_iam

  folder = local.folder_resource
  role   = each.value.role
  member = each.value.member
}

resource "google_billing_account_iam_member" "billing_viewer" {
  count = contains(keys(local.normalized_iam_groups), "billing_viewer") && var.billing_account != "" ? 1 : 0

  billing_account_id = var.billing_account
  role               = "roles/billing.viewer"
  member             = local.normalized_iam_groups["billing_viewer"]
}
