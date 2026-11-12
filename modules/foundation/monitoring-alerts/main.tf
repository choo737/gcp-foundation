locals {
  effective_pubsub_topic_id = var.alert_pubsub_topic_id != null ? trimspace(var.alert_pubsub_topic_id) : ""
  dlq_metric_filter         = "metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND resource.type=\"pubsub_subscription\" AND resource.labels.subscription_id=monitoring.regex.full_match(\".*dlq.*\")"
  workflows_metric_filter   = "metric.type=\"workflows.googleapis.com/finished_execution_count\" AND resource.type=\"workflows.googleapis.com/Workflow\" AND metric.labels.status=\"FAILED\""
  cloud_run_metric_filter   = "metric.type=\"run.googleapis.com/job/completed_execution_count\" AND resource.type=\"cloud_run_job\" AND metric.labels.result=\"failed\""
  bq_slots_metric_filter    = "metric.type=\"bigquery.googleapis.com/slots/allocated_for_project\" AND resource.type=\"global\""
  dataform_log_metric_name  = "${replace(var.prefix, "-", "_")}_${replace(var.environment, "-", "_")}_dataform_failures"

  notification_channel_ids = concat(
    [for ch in google_monitoring_notification_channel.email : ch.name],
    google_monitoring_notification_channel.pubsub[*].name,
  )
}

resource "google_monitoring_notification_channel" "email" {
  for_each = var.enable_alerts ? toset(var.alert_email_addresses) : toset([])

  project      = var.project_id
  display_name = "${var.prefix}-${var.environment} Alert Email (${each.value})"
  type         = "email"
  labels = {
    email_address = each.value
  }
  user_labels = var.labels
}

resource "google_monitoring_notification_channel" "pubsub" {
  count = var.enable_alerts && local.effective_pubsub_topic_id != "" ? 1 : 0

  project      = var.project_id
  display_name = "${var.prefix}-${var.environment} Alert Pub/Sub"
  type         = "pubsub"
  labels = {
    topic = local.effective_pubsub_topic_id
  }
  user_labels = var.labels
}

resource "google_logging_metric" "dataform_failures" {
  count = var.enable_alerts ? 1 : 0

  project     = var.project_id
  name        = local.dataform_log_metric_name
  description = "Counts Dataform API error log entries for workflow failure alerting."
  filter      = "protoPayload.serviceName=\"dataform.googleapis.com\" AND severity>=ERROR"

  metric_descriptor {
    metric_kind = "DELTA"
    value_type  = "INT64"
    unit        = "1"
  }
}

resource "google_monitoring_alert_policy" "pubsub_dlq_backlog" {
  count = var.enable_alerts ? 1 : 0

  project               = var.project_id
  display_name          = "${var.prefix}-${var.environment} Pub/Sub DLQ Backlog"
  combiner              = "OR"
  notification_channels = local.notification_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "Pub/Sub DLQ undelivered messages above threshold"

    condition_threshold {
      filter          = local.dlq_metric_filter
      comparison      = "COMPARISON_GT"
      threshold_value = var.dlq_backlog_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "workflows_failed" {
  count = var.enable_alerts ? 1 : 0

  project               = var.project_id
  display_name          = "${var.prefix}-${var.environment} Cloud Workflows Failures"
  combiner              = "OR"
  notification_channels = local.notification_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "Cloud Workflows failed execution count > 0"

    condition_threshold {
      filter          = local.workflows_metric_filter
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "cloud_run_job_failed" {
  count = var.enable_alerts ? 1 : 0

  project               = var.project_id
  display_name          = "${var.prefix}-${var.environment} Cloud Run Job Failures"
  combiner              = "OR"
  notification_channels = local.notification_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "Cloud Run Job failed execution count > 0"

    condition_threshold {
      filter          = local.cloud_run_metric_filter
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "bigquery_slot_saturation" {
  count = var.enable_alerts ? 1 : 0

  project               = var.project_id
  display_name          = "${var.prefix}-${var.environment} BigQuery Slot Saturation"
  combiner              = "OR"
  notification_channels = local.notification_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "BigQuery allocated slots above threshold"

    condition_threshold {
      filter          = local.bq_slots_metric_filter
      comparison      = "COMPARISON_GT"
      threshold_value = var.bigquery_slot_threshold
      duration        = "300s"

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_MEAN"
      }
    }
  }
}

resource "google_monitoring_alert_policy" "dataform_failures" {
  count = var.enable_alerts ? 1 : 0

  project               = var.project_id
  display_name          = "${var.prefix}-${var.environment} Dataform Invocation Failures"
  combiner              = "OR"
  notification_channels = local.notification_channel_ids
  user_labels           = var.labels

  conditions {
    display_name = "Dataform error log metric > 0"

    condition_threshold {
      filter          = "metric.type=\"logging.googleapis.com/user/${google_logging_metric.dataform_failures[0].name}\" AND resource.type=\"audited_resource\""
      comparison      = "COMPARISON_GT"
      threshold_value = 0
      duration        = "0s"

      aggregations {
        alignment_period   = "300s"
        per_series_aligner = "ALIGN_SUM"
      }
    }
  }
}
