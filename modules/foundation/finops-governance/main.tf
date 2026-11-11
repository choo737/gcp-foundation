locals {
  dataset_id = "${replace(var.prefix, "-", "_")}_billing_export"

  finops_tags = {
    cost_center = {
      description = "Chargeback cost center tag key."
      values = {
        platform = "Shared platform engineering workloads."
        data     = "Data platform storage and compute workloads."
        shared   = "Shared networking, security, and audit services."
      }
    }
    environment = {
      description = "Workload lifecycle environment tag key."
      values = {
        prod    = "Production workloads."
        nonprod = "Staging and pre-production workloads."
        sandbox = "Ephemeral validation workloads."
      }
    }
  }

  finops_tag_value_pairs = merge([
    for key_name, key_cfg in local.finops_tags : {
      for val_name, val_desc in key_cfg.values :
      "${key_name}.${val_name}" => {
        key_name    = key_name
        short_name  = val_name
        description = val_desc
      }
    }
  ]...)
}

resource "google_pubsub_topic" "budget_alerts" {
  project = var.audit_project_id
  name    = "${var.prefix}-finops-budget-alerts"
  labels  = var.labels
}

resource "google_billing_budget" "monthly" {
  count = var.enable_billing_budget ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${var.prefix}-foundation-monthly-budget"

  budget_filter {
    projects               = length(var.budget_project_numbers) > 0 ? [for num in var.budget_project_numbers : "projects/${num}"] : null
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = tostring(var.monthly_budget_amount)
    }
  }

  threshold_rules {
    threshold_percent = 0.5
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 0.8
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.0
    spend_basis       = "CURRENT_SPEND"
  }

  threshold_rules {
    threshold_percent = 1.1
    spend_basis       = "FORECASTED_SPEND"
  }

  all_updates_rule {
    pubsub_topic   = google_pubsub_topic.budget_alerts.id
    schema_version = "1.0"
  }
}

resource "google_bigquery_dataset" "billing_export" {
  project                    = var.audit_project_id
  dataset_id                 = local.dataset_id
  friendly_name              = "${var.prefix} Billing Export"
  description                = "Central FinOps dataset. Link Cloud Billing Standard and Detailed Usage Export here in Billing Console."
  location                   = var.region
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels
}

resource "google_bigquery_table" "finops_audit_jobs" {
  project             = var.audit_project_id
  dataset_id          = google_bigquery_dataset.billing_export.dataset_id
  table_id            = "v_finops_audit_project_jobs"
  description         = "Daily slot and billed TiB visibility over audit project BigQuery jobs."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  view {
    query          = <<-SQL
      SELECT
        DATE(creation_time) AS job_date,
        user_email,
        job_type,
        statement_type,
        COUNT(*) AS job_count,
        SUM(total_slot_ms) AS total_slot_ms,
        ROUND(SUM(total_bytes_billed) / POW(1024, 4), 6) AS total_billed_tib
      FROM `${var.audit_project_id}.region-${lower(var.region)}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
      WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      GROUP BY job_date, user_email, job_type, statement_type
    SQL
    use_legacy_sql = false
  }
}

resource "google_tags_tag_key" "finops" {
  for_each = local.finops_tags

  parent      = "projects/${var.audit_project_id}"
  short_name  = each.key
  description = each.value.description
}

resource "google_tags_tag_value" "finops" {
  for_each = local.finops_tag_value_pairs

  parent      = google_tags_tag_key.finops[each.value.key_name].id
  short_name  = each.value.short_name
  description = each.value.description
}
