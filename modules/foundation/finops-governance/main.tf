locals {
  trimmed_finops_project_id = var.finops_project_id != null ? trimspace(var.finops_project_id) : ""
  effective_project_id      = local.trimmed_finops_project_id != "" ? local.trimmed_finops_project_id : var.audit_project_id
  dataset_id                = "${replace(var.prefix, "-", "_")}_billing_export"

  clean_master_emails = distinct(compact([for e in var.alert_email_addresses : trimspace(e)]))
  all_alert_emails = toset(distinct(compact(concat(
    local.clean_master_emails,
    flatten([for w in values(var.workload_budgets) : [for e in w.alert_emails : trimspace(e)]]),
  ))))

  master_channel_ids = [
    for e in local.clean_master_emails :
    google_monitoring_notification_channel.budget_email[e].name
  ]

  clean_env_folder_ids = {
    for env, fid in var.environment_folder_ids :
    env => trimspace(fid) != "" ? "folders/${replace(trimspace(fid), "folders/", "")}" : ""
  }

  workload_budget_configs = {
    for k, w in var.workload_budgets :
    k => {
      amount   = w.amount
      projects = w.projects
      labels   = w.labels
      channel_ids = length(distinct(compact([for e in w.alert_emails : trimspace(e)]))) > 0 ? [
        for e in distinct(compact([for x in w.alert_emails : trimspace(x)])) :
        google_monitoring_notification_channel.budget_email[e].name
      ] : local.master_channel_ids
    }
  }

  trimmed_finops_admins = var.finops_admins_group != null ? trimspace(var.finops_admins_group) : ""
  finops_admins_member = local.trimmed_finops_admins != "" ? (
    startswith(local.trimmed_finops_admins, "group:") || startswith(local.trimmed_finops_admins, "user:") || startswith(local.trimmed_finops_admins, "serviceAccount:")
    ? local.trimmed_finops_admins
    : "group:${local.trimmed_finops_admins}"
  ) : ""
  trimmed_billing_export_table = var.billing_export_table_name != null ? trimspace(var.billing_export_table_name) : ""

  department_budget_scopes = {
    for k, _ in var.department_budgets :
    k => {
      ancestors = [
        for item in lookup(var.department_budget_ancestors, k, []) :
        item if startswith(item, "folders/") || startswith(item, "organizations/")
      ]
      projects = [
        for item in lookup(var.department_budget_ancestors, k, []) :
        item if startswith(item, "projects/")
      ]
    }
  }

  finops_tags = {
    cost_center = {
      description = "Chargeback cost center tag key."
      values = {
        platform = "Shared platform engineering workloads."
        shared   = "Shared networking, security, and audit services."
        data     = "Data platform storage and compute workloads."
        ai       = "AI experimentation and MLOps workloads."
        app      = "Application team runtime workloads."
        security = "Dedicated SecOps and Security Command Center workloads."
        network  = "Shared VPC and network perimeter infrastructure."
      }
    }
    environment = {
      description = "Workload lifecycle environment tag key."
      values = {
        prod    = "Production workloads."
        uat     = "User acceptance testing workloads."
        nonprod = "Development and pre-production workloads."
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
  project = local.effective_project_id
  name    = "${var.prefix}-finops-budget-alerts"
  labels  = var.labels
}

resource "google_monitoring_notification_channel" "budget_email" {
  for_each = var.enable_billing_budget ? local.all_alert_emails : toset([])

  project      = local.effective_project_id
  display_name = "${var.prefix} FinOps Budget Alert (${each.value})"
  type         = "email"
  labels = {
    email_address = each.value
  }
  user_labels = var.labels
}

resource "google_billing_budget" "monthly" {
  count = var.enable_billing_budget ? 1 : 0

  billing_account = var.billing_account
  display_name    = "${var.prefix}-foundation-monthly-budget"

  budget_filter {
    projects               = length(var.budget_project_numbers) > 0 ? [for num in var.budget_project_numbers : startswith(trimspace(num), "projects/") ? trimspace(num) : "projects/${trimspace(num)}"] : null
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = tostring(var.monthly_budget_amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.enable_forecasted_threshold ? [1.0] : []
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = length(local.master_channel_ids) > 0 ? slice(local.master_channel_ids, 0, min(length(local.master_channel_ids), 5)) : null
    disable_default_iam_recipients   = var.disable_default_iam_recipients
  }

  lifecycle {
    precondition {
      condition     = length(local.master_channel_ids) <= 5
      error_message = "Cloud Billing budgets support at most 5 monitoring_notification_channels."
    }
  }
}

resource "google_billing_budget" "environment" {
  for_each = var.enable_billing_budget ? var.environment_budgets : {}

  billing_account = var.billing_account
  display_name    = "${var.prefix}-env-${each.key}-monthly-budget"

  budget_filter {
    resource_ancestors     = lookup(local.clean_env_folder_ids, each.key, "") != "" ? [local.clean_env_folder_ids[each.key]] : null
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = tostring(each.value)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.enable_forecasted_threshold ? [1.0] : []
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = length(local.master_channel_ids) > 0 ? slice(local.master_channel_ids, 0, min(length(local.master_channel_ids), 5)) : null
    disable_default_iam_recipients   = var.disable_default_iam_recipients
  }

  lifecycle {
    precondition {
      condition     = lookup(local.clean_env_folder_ids, each.key, "") != ""
      error_message = "environment_folder_ids must contain a folder ID for every key in environment_budgets."
    }

    precondition {
      condition     = length(local.master_channel_ids) <= 5
      error_message = "Cloud Billing budgets support at most 5 monitoring_notification_channels."
    }
  }
}

resource "google_billing_budget" "workload" {
  for_each = var.enable_billing_budget ? local.workload_budget_configs : {}

  billing_account = var.billing_account
  display_name    = "${var.prefix}-workload-${each.key}-monthly-budget"

  budget_filter {
    projects               = length(each.value.projects) > 0 ? [for p in each.value.projects : startswith(p, "projects/") ? p : "projects/${p}"] : null
    labels                 = length(each.value.labels) > 0 ? each.value.labels : null
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = tostring(each.value.amount)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.enable_forecasted_threshold ? [1.0] : []
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = length(each.value.channel_ids) > 0 ? slice(each.value.channel_ids, 0, min(length(each.value.channel_ids), 5)) : null
    disable_default_iam_recipients   = var.disable_default_iam_recipients
  }

  depends_on = []

  lifecycle {
    precondition {
      condition     = length(each.value.projects) > 0 || length(each.value.labels) > 0
      error_message = "Each workload_budgets entry must specify at least one project or label filter."
    }

    precondition {
      condition     = length(each.value.channel_ids) <= 5
      error_message = "Cloud Billing budgets support at most 5 monitoring_notification_channels."
    }
  }
}

resource "google_billing_budget" "department" {
  for_each = var.enable_billing_budget ? var.department_budgets : {}

  billing_account = var.billing_account
  display_name    = "${var.prefix}-dept-${each.key}-monthly-budget"

  budget_filter {
    resource_ancestors     = length(local.department_budget_scopes[each.key].ancestors) > 0 ? toset(local.department_budget_scopes[each.key].ancestors) : null
    projects               = length(local.department_budget_scopes[each.key].ancestors) == 0 && length(local.department_budget_scopes[each.key].projects) > 0 ? toset(local.department_budget_scopes[each.key].projects) : null
    credit_types_treatment = "INCLUDE_ALL_CREDITS"
  }

  amount {
    specified_amount {
      currency_code = var.budget_currency_code
      units         = tostring(each.value)
    }
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  dynamic "threshold_rules" {
    for_each = var.enable_forecasted_threshold ? [1.0] : []
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "FORECASTED_SPEND"
    }
  }

  all_updates_rule {
    pubsub_topic                     = google_pubsub_topic.budget_alerts.id
    schema_version                   = "1.0"
    monitoring_notification_channels = length(local.master_channel_ids) > 0 ? slice(local.master_channel_ids, 0, min(length(local.master_channel_ids), 5)) : null
    disable_default_iam_recipients   = var.disable_default_iam_recipients
  }

  lifecycle {
    precondition {
      condition     = length(local.master_channel_ids) <= 5
      error_message = "Cloud Billing budgets support at most 5 monitoring_notification_channels."
    }

    precondition {
      condition     = length(local.department_budget_scopes[each.key].ancestors) > 0 || length(local.department_budget_scopes[each.key].projects) > 0
      error_message = "department_budget_ancestors must provide folders/, organizations/, or projects/ for every department_budgets key; Cloud Billing budgets ignore RM tags and project labels."
    }
  }
}

resource "google_bigquery_dataset" "billing_export" {
  project                    = local.effective_project_id
  dataset_id                 = local.dataset_id
  friendly_name              = "${var.prefix} Billing Export"
  description                = "Central FinOps dataset. Link Cloud Billing Standard and Detailed Usage Export here in Billing Console."
  location                   = var.billing_export_location
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels
}

resource "google_bigquery_table" "finops_audit_jobs" {
  project             = local.effective_project_id
  dataset_id          = google_bigquery_dataset.billing_export.dataset_id
  table_id            = "v_finops_audit_project_jobs"
  description         = "Daily slot and billed TiB visibility over FinOps project BigQuery jobs."
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
      FROM `${local.effective_project_id}.region-${lower(var.billing_export_location)}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
      WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
      GROUP BY job_date, user_email, job_type, statement_type
    SQL
    use_legacy_sql = false
  }
}

resource "google_tags_tag_key" "finops" {
  for_each = local.finops_tags

  parent      = "projects/${local.effective_project_id}"
  short_name  = each.key
  description = each.value.description
}

resource "google_tags_tag_value" "finops" {
  for_each = local.finops_tag_value_pairs

  parent      = google_tags_tag_key.finops[each.value.key_name].id
  short_name  = each.value.short_name
  description = each.value.description
}

resource "google_bigquery_table" "department_spend_view" {
  count = local.trimmed_billing_export_table != "" ? 1 : 0

  project             = local.effective_project_id
  dataset_id          = google_bigquery_dataset.billing_export.dataset_id
  table_id            = "v_finops_department_spend"
  description         = "Monthly net spend grouped by cost_center and environment labels."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  view {
    query          = <<-SQL
      SELECT
        invoice.month AS invoice_month,
        COALESCE(
          (SELECT t.value FROM UNNEST(tags) AS t WHERE t.key = 'cost_center' OR ENDS_WITH(t.key, '/cost_center') LIMIT 1),
          (SELECT l.value FROM UNNEST(labels) AS l WHERE l.key = 'cost_center' LIMIT 1),
          (SELECT pl.value FROM UNNEST(project.labels) AS pl WHERE pl.key = 'cost_center' LIMIT 1),
          'unallocated'
        ) AS cost_center,
        COALESCE(
          (SELECT t.value FROM UNNEST(tags) AS t WHERE t.key = 'environment' OR ENDS_WITH(t.key, '/environment') LIMIT 1),
          (SELECT l.value FROM UNNEST(labels) AS l WHERE l.key = 'environment' LIMIT 1),
          (SELECT pl.value FROM UNNEST(project.labels) AS pl WHERE pl.key = 'environment' LIMIT 1),
          'unallocated'
        ) AS environment,
        currency,
        ROUND(SUM(cost) + SUM(IFNULL((SELECT SUM(c.amount) FROM UNNEST(credits) AS c), 0)), 2) AS net_cost
      FROM `${local.effective_project_id}.${google_bigquery_dataset.billing_export.dataset_id}.${local.trimmed_billing_export_table}`
      GROUP BY invoice_month, cost_center, environment, currency
    SQL
    use_legacy_sql = false
  }
}

resource "google_billing_account_iam_member" "finops_admins_costs_manager" {
  count = local.finops_admins_member != "" && var.billing_account != "" ? 1 : 0

  billing_account_id = var.billing_account
  role               = "roles/billing.costsManager"
  member             = local.finops_admins_member
}

resource "google_project_iam_member" "finops_admins_bq_viewer" {
  count = local.finops_admins_member != "" ? 1 : 0

  project = local.effective_project_id
  role    = "roles/bigquery.dataViewer"
  member  = local.finops_admins_member
}

resource "google_project_iam_member" "finops_admins_bq_job_user" {
  count = local.finops_admins_member != "" ? 1 : 0

  project = local.effective_project_id
  role    = "roles/bigquery.jobUser"
  member  = local.finops_admins_member
}
