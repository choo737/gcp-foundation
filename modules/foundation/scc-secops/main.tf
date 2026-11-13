locals {
  enable_standard = contains(["STANDARD", "PREMIUM"], var.scc_tier)
  enable_premium  = var.scc_tier == "PREMIUM"

  numeric_folder_id    = replace(var.folder_id, "folders/", "")
  trimmed_kms_key_id   = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  effective_kms_key_id = local.trimmed_kms_key_id
  trimmed_org_id       = var.organization_id != null ? trimspace(var.organization_id) : ""
  numeric_org_id       = replace(local.trimmed_org_id, "organizations/", "")

  prod_folder_raw = lookup(var.environment_folder_ids, "prod", "")
  prod_folder_id  = trimspace(local.prod_folder_raw) != "" ? replace(trimspace(local.prod_folder_raw), "folders/", "") : local.numeric_folder_id

  nonprod_mute_folders = local.enable_standard && var.enable_nonprod_mute_rules ? {
    for env, fid in var.environment_folder_ids :
    env => replace(trimspace(fid), "folders/", "")
    if contains(var.nonprod_mute_environments, env) && trimspace(fid) != ""
  } : {}

  alert_channel_ids = [
    for ch in google_monitoring_notification_channel.scc_email : ch.name
  ]
}

resource "terraform_data" "validate_security_posture" {
  lifecycle {
    precondition {
      condition     = !(local.enable_premium && var.enable_security_posture) || local.numeric_org_id != ""
      error_message = "organization_id is required when enable_security_posture is true in PREMIUM tier."
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

resource "google_scc_v2_folder_scc_big_query_export" "active_findings" {
  count = local.enable_standard && var.enable_bigquery_export ? 1 : 0

  big_query_export_id = "${var.prefix}-scc-bq-export"
  folder              = local.numeric_folder_id
  location            = var.scc_location
  dataset             = "projects/${var.audit_project_id}/datasets/${google_bigquery_dataset.scc_findings[0].dataset_id}"
  filter              = "state=\"ACTIVE\" AND NOT mute=\"MUTED\""
  description         = "Continuous export of active unmuted SCC v2 findings to regional BigQuery."
}

resource "google_bigquery_dataset_iam_member" "scc_export_writer" {
  count = local.enable_standard && var.enable_bigquery_export ? 1 : 0

  project    = var.audit_project_id
  dataset_id = google_bigquery_dataset.scc_findings[0].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = startswith(google_scc_v2_folder_scc_big_query_export.active_findings[0].principal, "serviceAccount:") ? google_scc_v2_folder_scc_big_query_export.active_findings[0].principal : "serviceAccount:${google_scc_v2_folder_scc_big_query_export.active_findings[0].principal}"
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
}

resource "google_scc_v2_folder_notification_config" "high_critical" {
  count = local.enable_standard && var.enable_pubsub_notifications ? 1 : 0

  config_id    = "${var.prefix}-scc-high-crit"
  folder       = local.numeric_folder_id
  location     = var.scc_location
  pubsub_topic = google_pubsub_topic.scc_findings[0].id
  description  = "Stream active unmuted HIGH and CRITICAL SCC findings to Pub/Sub."

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
  display_name          = "${var.prefix} SCC High and Critical Unacked Findings"
  combiner              = "OR"
  notification_channels = local.alert_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "Unacknowledged SCC high or critical findings > 0"

    condition_threshold {
      filter          = "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=\"${google_pubsub_subscription.scc_findings_alert[0].name}\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }
}

resource "google_scc_management_folder_security_health_analytics_custom_module" "prod_bq_cmek" {
  count = local.enable_premium && var.enable_custom_sha_modules ? 1 : 0

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

resource "google_scc_management_folder_security_health_analytics_custom_module" "gcs_ubla" {
  count = local.enable_premium && var.enable_custom_sha_modules ? 1 : 0

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

resource "google_securityposture_posture" "foundation" {
  count = local.enable_premium && var.enable_security_posture && local.numeric_org_id != "" ? 1 : 0

  posture_id  = "${var.prefix}-foundation-posture"
  parent      = "organizations/${local.numeric_org_id}"
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
  count = local.enable_premium && var.enable_security_posture && local.numeric_org_id != "" ? 1 : 0

  posture_deployment_id = "${var.prefix}-root-posture-deploy"
  parent                = "organizations/${local.numeric_org_id}"
  location              = "global"
  description           = "Deploy foundation posture drift monitoring onto the root folder."
  target_resource       = "folders/${local.numeric_folder_id}"
  posture_id            = google_securityposture_posture.foundation[0].name
  posture_revision_id   = google_securityposture_posture.foundation[0].revision_id
}
