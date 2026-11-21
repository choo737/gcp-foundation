locals {
  enable_standard = contains(["STANDARD", "PREMIUM"], var.scc_tier)
  enable_premium  = var.scc_tier == "PREMIUM"

  trimmed_folder_id = trimspace(var.folder_id)
  parent_is_org     = startswith(local.trimmed_folder_id, "organizations/")

  is_project_scope = var.scc_scope == "PROJECT"
  is_org_scope     = var.scc_scope == "ORGANIZATION" || (var.scc_scope == "FOLDER" && local.parent_is_org)
  is_folder_scope  = var.scc_scope == "FOLDER" && !local.parent_is_org

  numeric_folder_id      = !local.parent_is_org ? replace(local.trimmed_folder_id, "folders/", "") : ""
  trimmed_kms_key_id     = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  effective_kms_key_id   = local.trimmed_kms_key_id
  trimmed_org_id         = var.organization_id != null ? trimspace(var.organization_id) : ""
  numeric_org_id         = replace(local.trimmed_org_id, "organizations/", "")
  effective_org_id_num   = local.numeric_org_id != "" ? local.numeric_org_id : (local.parent_is_org ? replace(local.trimmed_folder_id, "organizations/", "") : "")
  parent_target_resource = local.parent_is_org ? "organizations/${replace(local.trimmed_folder_id, "organizations/", "")}" : "folders/${local.numeric_folder_id}"
  trimmed_siem_push_url  = var.siem_push_endpoint != null ? trimspace(var.siem_push_endpoint) : ""
  trimmed_etd_config     = var.custom_etd_config_json != null ? trimspace(var.custom_etd_config_json) : ""
  trimmed_etd_name       = var.custom_etd_display_name != null ? trimspace(var.custom_etd_display_name) : ""
  effective_etd_name     = local.trimmed_etd_name != "" ? local.trimmed_etd_name : "${replace(var.prefix, "-", "_")}_custom_etd_detector"

  clean_target_projects = distinct(compact([for p in var.scc_target_project_ids : trimspace(p)]))
  effective_project_ids = local.is_project_scope ? (length(local.clean_target_projects) > 0 ? local.clean_target_projects : [var.audit_project_id]) : []

  prod_folder_raw     = lookup(var.environment_folder_ids, "prod", "")
  has_prod_env_folder = trimspace(local.prod_folder_raw) != ""
  prod_folder_id      = local.has_prod_env_folder ? replace(trimspace(local.prod_folder_raw), "folders/", "") : local.numeric_folder_id

  nonprod_mute_folders = local.enable_standard && var.enable_nonprod_mute_rules && (local.is_org_scope || local.is_folder_scope) ? {
    for env, fid in var.environment_folder_ids :
    env => replace(trimspace(fid), "folders/", "")
    if contains(var.nonprod_mute_environments, env) && trimspace(fid) != ""
  } : {}

  trimmed_secops_analysts = var.secops_analysts_group != null ? trimspace(var.secops_analysts_group) : ""
  secops_analysts_member = local.trimmed_secops_analysts != "" ? (
    startswith(local.trimmed_secops_analysts, "group:") || startswith(local.trimmed_secops_analysts, "user:") || startswith(local.trimmed_secops_analysts, "serviceAccount:")
    ? local.trimmed_secops_analysts
    : "group:${local.trimmed_secops_analysts}"
  ) : ""

  alert_channel_ids = [
    for ch in google_monitoring_notification_channel.scc_email : ch.name
  ]
}

resource "terraform_data" "validate_security_posture" {
  lifecycle {
    precondition {
      condition     = !local.is_org_scope || local.effective_org_id_num != ""
      error_message = "organization_id or an organizations/<id> parent is required for organization-scoped SCC resources."
    }

    precondition {
      condition     = !(local.enable_premium && var.enable_security_posture) || local.effective_org_id_num != ""
      error_message = "organization_id is required when enable_security_posture is true in PREMIUM tier."
    }

    precondition {
      condition     = !(local.enable_premium && var.enable_custom_etd_module) || (local.effective_org_id_num != "" && local.trimmed_etd_config != "")
      error_message = "organization_id and custom_etd_config_json are required when enable_custom_etd_module is true."
    }
  }
}

resource "google_bigquery_dataset" "scc_findings" {
  count = local.enable_standard && var.enable_bigquery_export ? 1 : 0

  project                    = var.audit_project_id
  dataset_id                 = "${replace(var.prefix, "-", "_")}_scc_findings"
  friendly_name              = "${var.prefix} SCC Findings"
  description                = "Regional Security Command Center v2 findings export dataset."
  location                   = var.region
  max_time_travel_hours      = 168
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels

  dynamic "default_encryption_configuration" {
    for_each = local.effective_kms_key_id != "" ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }
}

resource "google_scc_v2_organization_scc_big_query_export" "org_active_findings" {
  count = local.enable_standard && var.enable_bigquery_export && local.is_org_scope ? 1 : 0

  big_query_export_id = "${var.prefix}-scc-bq-export"
  organization        = local.effective_org_id_num
  location            = var.scc_location
  dataset             = "projects/${var.audit_project_id}/datasets/${google_bigquery_dataset.scc_findings[0].dataset_id}"
  filter              = "state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  description         = "Continuous organization export of active unmuted SCC v2 findings to regional BigQuery."
}

resource "google_bigquery_dataset_iam_member" "scc_org_export_writer" {
  count = local.enable_standard && var.enable_bigquery_export && local.is_org_scope ? 1 : 0

  project    = var.audit_project_id
  dataset_id = google_bigquery_dataset.scc_findings[0].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = startswith(google_scc_v2_organization_scc_big_query_export.org_active_findings[0].principal, "serviceAccount:") ? google_scc_v2_organization_scc_big_query_export.org_active_findings[0].principal : "serviceAccount:${google_scc_v2_organization_scc_big_query_export.org_active_findings[0].principal}"
}

resource "google_scc_v2_folder_scc_big_query_export" "active_findings" {
  count = local.enable_standard && var.enable_bigquery_export && local.is_folder_scope ? 1 : 0

  big_query_export_id = "${var.prefix}-scc-bq-export"
  folder              = local.numeric_folder_id
  location            = var.scc_location
  dataset             = "projects/${var.audit_project_id}/datasets/${google_bigquery_dataset.scc_findings[0].dataset_id}"
  filter              = "state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  description         = "Continuous export of active unmuted SCC v2 findings to regional BigQuery."
}

resource "google_bigquery_dataset_iam_member" "scc_export_writer" {
  count = local.enable_standard && var.enable_bigquery_export && local.is_folder_scope ? 1 : 0

  project    = var.audit_project_id
  dataset_id = google_bigquery_dataset.scc_findings[0].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = startswith(google_scc_v2_folder_scc_big_query_export.active_findings[0].principal, "serviceAccount:") ? google_scc_v2_folder_scc_big_query_export.active_findings[0].principal : "serviceAccount:${google_scc_v2_folder_scc_big_query_export.active_findings[0].principal}"
}

resource "google_scc_v2_project_scc_big_query_export" "project_active_findings" {
  for_each = local.enable_standard && var.enable_bigquery_export && local.is_project_scope ? toset(local.effective_project_ids) : toset([])

  big_query_export_id = substr("${var.prefix}-${replace(each.value, "_", "-")}-scc-bq", 0, 63)
  project             = each.value
  location            = var.scc_location
  dataset             = "projects/${var.audit_project_id}/datasets/${google_bigquery_dataset.scc_findings[0].dataset_id}"
  filter              = "state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  description         = "Continuous project-scoped export of active unmuted SCC v2 findings to regional BigQuery."
}

resource "google_bigquery_dataset_iam_member" "scc_project_export_writer" {
  for_each = local.enable_standard && var.enable_bigquery_export && local.is_project_scope ? toset(local.effective_project_ids) : toset([])

  project    = var.audit_project_id
  dataset_id = google_bigquery_dataset.scc_findings[0].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = startswith(google_scc_v2_project_scc_big_query_export.project_active_findings[each.key].principal, "serviceAccount:") ? google_scc_v2_project_scc_big_query_export.project_active_findings[each.key].principal : "serviceAccount:${google_scc_v2_project_scc_big_query_export.project_active_findings[each.key].principal}"
}

resource "google_pubsub_topic" "scc_findings" {
  count = local.enable_standard && var.enable_pubsub_notifications ? 1 : 0

  project      = var.audit_project_id
  name         = "${var.prefix}-scc-findings"
  kms_key_name = local.effective_kms_key_id != "" ? local.effective_kms_key_id : null
  labels       = var.labels
}

resource "google_pubsub_subscription" "scc_findings_alert" {
  count = local.enable_standard && var.enable_pubsub_notifications ? 1 : 0

  project                    = var.audit_project_id
  name                       = "${var.prefix}-scc-findings-alert-sub"
  topic                      = google_pubsub_topic.scc_findings[0].id
  message_retention_duration = "604800s"
  ack_deadline_seconds       = 60
  labels                     = var.labels

  dynamic "push_config" {
    for_each = local.trimmed_siem_push_url != "" ? [local.trimmed_siem_push_url] : []
    content {
      push_endpoint = push_config.value
    }
  }
}

resource "google_scc_v2_organization_notification_config" "org_high_critical" {
  count = local.enable_standard && var.enable_pubsub_notifications && local.is_org_scope ? 1 : 0

  config_id    = "${var.prefix}-scc-high-crit"
  organization = local.effective_org_id_num
  location     = var.scc_location
  pubsub_topic = google_pubsub_topic.scc_findings[0].id
  description  = "Stream organization active unmuted HIGH and CRITICAL SCC findings to Pub/Sub."

  streaming_config {
    filter = "(severity=\"HIGH\" OR severity=\"CRITICAL\") AND state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  }
}

resource "google_scc_v2_folder_notification_config" "high_critical" {
  count = local.enable_standard && var.enable_pubsub_notifications && local.is_folder_scope ? 1 : 0

  config_id    = "${var.prefix}-scc-high-crit"
  folder       = local.numeric_folder_id
  location     = var.scc_location
  pubsub_topic = google_pubsub_topic.scc_findings[0].id
  description  = "Stream active unmuted HIGH and CRITICAL SCC findings to Pub/Sub."

  streaming_config {
    filter = "(severity=\"HIGH\" OR severity=\"CRITICAL\") AND state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  }
}

resource "google_scc_v2_project_notification_config" "project_high_critical" {
  for_each = local.enable_standard && var.enable_pubsub_notifications && local.is_project_scope ? toset(local.effective_project_ids) : toset([])

  config_id    = substr("${var.prefix}-scc-hc-${replace(each.value, "_", "-")}", 0, 63)
  project      = each.value
  location     = var.scc_location
  pubsub_topic = google_pubsub_topic.scc_findings[0].id
  description  = "Stream project-scoped active unmuted HIGH and CRITICAL SCC findings to Pub/Sub."

  streaming_config {
    filter = "(severity=\"HIGH\" OR severity=\"CRITICAL\") AND state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  }
}

resource "google_scc_v2_folder_mute_config" "nonprod" {
  for_each = local.nonprod_mute_folders

  mute_config_id = "${var.prefix}-${each.key}-nonprod-mute"
  folder         = each.value
  location       = var.scc_location
  type           = "DYNAMIC"
  filter         = var.nonprod_mute_filter
  description    = "Mute expected non-production posture findings in ${each.key}."
}

resource "google_monitoring_notification_channel" "scc_email" {
  for_each = local.enable_standard && var.enable_pubsub_notifications ? toset(var.alert_email_addresses) : toset([])

  project      = var.audit_project_id
  display_name = "${var.prefix} SCC Alert Email (${each.value})"
  type         = "email"
  labels = {
    email_address = each.value
  }
  user_labels = var.labels
}

resource "google_monitoring_alert_policy" "scc_unacked_findings" {
  count = local.enable_standard && var.enable_pubsub_notifications ? 1 : 0

  project               = var.audit_project_id
  display_name          = "${var.prefix} SCC High and Critical Findings Published"
  combiner              = "OR"
  notification_channels = local.alert_channel_ids
  user_labels           = var.labels

  alert_strategy {
    auto_close = "1800s"
  }

  conditions {
    display_name = "SCC high or critical finding published to Pub/Sub topic > 0"

    condition_threshold {
      filter          = "metric.type=\"pubsub.googleapis.com/topic/send_message_operation_count\" AND resource.type=\"pubsub_topic\" AND resource.labels.topic_id=\"${google_pubsub_topic.scc_findings[0].name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}

resource "google_scc_management_folder_security_health_analytics_custom_module" "prod_bq_cmek" {
  count = local.enable_premium && var.enable_custom_sha_modules && ((local.is_folder_scope && local.prod_folder_id != "") || (local.is_org_scope && local.has_prod_env_folder)) ? 1 : 0

  folder           = local.prod_folder_id
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_prod_bq_cmek_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "Production BigQuery datasets must enforce customer-managed encryption keys (CMEK)."
    recommendation = "Configure default_encryption_configuration.kms_key_name on the BigQuery dataset."

    resource_selector {
      resource_types = ["bigquery.googleapis.com/Dataset"]
    }

    predicate {
      expression = "!has(resource.defaultEncryptionConfiguration) || resource.defaultEncryptionConfiguration.kmsKeyName == \"\""
      title      = "Missing BigQuery Dataset CMEK"
    }
  }
}

resource "google_scc_management_organization_security_health_analytics_custom_module" "org_prod_bq_cmek" {
  count = local.enable_premium && var.enable_custom_sha_modules && local.is_org_scope && !local.has_prod_env_folder ? 1 : 0

  organization     = local.effective_org_id_num
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_prod_bq_cmek_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "Production BigQuery datasets must enforce customer-managed encryption keys (CMEK)."
    recommendation = "Configure default_encryption_configuration.kms_key_name on the BigQuery dataset."

    resource_selector {
      resource_types = ["bigquery.googleapis.com/Dataset"]
    }

    predicate {
      expression = "!has(resource.defaultEncryptionConfiguration) || resource.defaultEncryptionConfiguration.kmsKeyName == \"\""
      title      = "Missing BigQuery Dataset CMEK"
    }
  }
}

resource "google_scc_management_folder_security_health_analytics_custom_module" "gcs_ubla" {
  count = local.enable_premium && var.enable_custom_sha_modules && local.is_folder_scope ? 1 : 0

  folder           = local.numeric_folder_id
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_gcs_uniform_access_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "Cloud Storage buckets must enable Uniform Bucket-Level Access."
    recommendation = "Enable uniform_bucket_level_access on the Cloud Storage bucket."

    resource_selector {
      resource_types = ["storage.googleapis.com/Bucket"]
    }

    predicate {
      expression = "!has(resource.iamConfiguration) || !has(resource.iamConfiguration.uniformBucketLevelAccess) || !resource.iamConfiguration.uniformBucketLevelAccess.enabled"
      title      = "Uniform Bucket-Level Access Disabled"
    }
  }
}

resource "google_scc_management_organization_security_health_analytics_custom_module" "org_gcs_ubla" {
  count = local.enable_premium && var.enable_custom_sha_modules && local.is_org_scope ? 1 : 0

  organization     = local.effective_org_id_num
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_gcs_uniform_access_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "Cloud Storage buckets must enable Uniform Bucket-Level Access."
    recommendation = "Enable uniform_bucket_level_access on the Cloud Storage bucket."

    resource_selector {
      resource_types = ["storage.googleapis.com/Bucket"]
    }

    predicate {
      expression = "!has(resource.iamConfiguration) || !has(resource.iamConfiguration.uniformBucketLevelAccess) || !resource.iamConfiguration.uniformBucketLevelAccess.enabled"
      title      = "Uniform Bucket-Level Access Disabled"
    }
  }
}

resource "google_scc_management_project_security_health_analytics_custom_module" "project_prod_bq_cmek" {
  for_each = local.enable_premium && var.enable_custom_sha_modules && local.is_project_scope ? toset(local.effective_project_ids) : toset([])

  project          = each.value
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_proj_bq_cmek_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "BigQuery datasets must enforce customer-managed encryption keys (CMEK)."
    recommendation = "Configure default_encryption_configuration.kms_key_name on the BigQuery dataset."

    resource_selector {
      resource_types = ["bigquery.googleapis.com/Dataset"]
    }

    predicate {
      expression = "!has(resource.defaultEncryptionConfiguration) || resource.defaultEncryptionConfiguration.kmsKeyName == \"\""
      title      = "Missing BigQuery Dataset CMEK"
    }
  }
}

resource "google_scc_management_project_security_health_analytics_custom_module" "project_gcs_ubla" {
  for_each = local.enable_premium && var.enable_custom_sha_modules && local.is_project_scope ? toset(local.effective_project_ids) : toset([])

  project          = each.value
  location         = "global"
  display_name     = "${replace(var.prefix, "-", "_")}_proj_gcs_uniform_access_required"
  enablement_state = "ENABLED"

  custom_config {
    severity       = "HIGH"
    description    = "Cloud Storage buckets must enable Uniform Bucket-Level Access."
    recommendation = "Enable uniform_bucket_level_access on the Cloud Storage bucket."

    resource_selector {
      resource_types = ["storage.googleapis.com/Bucket"]
    }

    predicate {
      expression = "!has(resource.iamConfiguration) || !has(resource.iamConfiguration.uniformBucketLevelAccess) || !resource.iamConfiguration.uniformBucketLevelAccess.enabled"
      title      = "Uniform Bucket-Level Access Disabled"
    }
  }
}

resource "google_scc_management_organization_event_threat_detection_custom_module" "this" {
  count = local.enable_premium && var.enable_custom_etd_module && local.effective_org_id_num != "" && local.trimmed_etd_config != "" ? 1 : 0

  organization     = local.effective_org_id_num
  location         = "global"
  display_name     = local.effective_etd_name
  enablement_state = "ENABLED"
  type             = var.custom_etd_type
  config           = local.trimmed_etd_config

  depends_on = [terraform_data.validate_security_posture]
}

resource "google_securityposture_posture" "foundation" {
  count = local.enable_premium && var.enable_security_posture && local.effective_org_id_num != "" ? 1 : 0

  posture_id  = "${var.prefix}-foundation-posture"
  parent      = "organizations/${local.effective_org_id_num}"
  location    = "global"
  state       = "ACTIVE"
  description = "Continuous drift posture for key Org Policy guardrails."

  policy_sets {
    policy_set_id = "foundation_org_policies"
    description   = "Core foundation Org Policy drift guardrails."

    policies {
      policy_id   = "enforce_storage_uniform_bucket_level_access"
      description = "Require Uniform Bucket-Level Access on Cloud Storage buckets."
      constraint {
        org_policy_constraint {
          canned_constraint_id = "storage.uniformBucketLevelAccess"
          policy_rules {
            enforce = true
          }
        }
      }
    }

    policies {
      policy_id   = "enforce_disable_sa_key_creation"
      description = "Prevent user-managed service account key creation."
      constraint {
        org_policy_constraint {
          canned_constraint_id = "iam.disableServiceAccountKeyCreation"
          policy_rules {
            enforce = true
          }
        }
      }
    }

    policies {
      policy_id   = "enforce_sql_restrict_public_ip"
      description = "Prevent public IP assignment on Cloud SQL instances."
      constraint {
        org_policy_constraint {
          canned_constraint_id = "sql.restrictPublicIp"
          policy_rules {
            enforce = true
          }
        }
      }
    }
  }

  depends_on = [terraform_data.validate_security_posture]
}

resource "google_securityposture_posture_deployment" "root_folder" {
  count = local.enable_premium && var.enable_security_posture && local.effective_org_id_num != "" ? 1 : 0

  posture_deployment_id = "${var.prefix}-root-posture-deploy"
  parent                = "organizations/${local.effective_org_id_num}"
  location              = "global"
  description           = "Deploy foundation posture drift monitoring onto the root organization or folder."
  target_resource       = local.parent_target_resource
  posture_id            = google_securityposture_posture.foundation[0].name
  posture_revision_id   = google_securityposture_posture.foundation[0].revision_id
}

resource "google_project_iam_member" "secops_analysts_bq_viewer" {
  count = local.secops_analysts_member != "" ? 1 : 0

  project = var.audit_project_id
  role    = "roles/bigquery.dataViewer"
  member  = local.secops_analysts_member
}

resource "google_project_iam_member" "secops_analysts_bq_job_user" {
  count = local.secops_analysts_member != "" ? 1 : 0

  project = var.audit_project_id
  role    = "roles/bigquery.jobUser"
  member  = local.secops_analysts_member
}
