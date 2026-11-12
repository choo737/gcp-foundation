locals {
  trimmed_quality_project_id    = var.quality_target_project_id != null ? trimspace(var.quality_target_project_id) : ""
  effective_quality_project_id  = local.trimmed_quality_project_id != "" ? local.trimmed_quality_project_id : var.project_id
  trimmed_quality_dataset_id    = var.quality_target_dataset_id != null ? trimspace(var.quality_target_dataset_id) : ""
  effective_quality_dataset_id  = local.trimmed_quality_dataset_id != "" ? local.trimmed_quality_dataset_id : "${replace(var.prefix, "-", "_")}_silver_curated"
  trimmed_quality_results_table = var.quality_results_table != null ? trimspace(var.quality_results_table) : ""
  trimmed_quarantine_dataset    = var.quarantine_dataset_id != null ? trimspace(var.quarantine_dataset_id) : ""

  effective_quality_results_table = (
    local.trimmed_quality_results_table != ""
    ? local.trimmed_quality_results_table
    : (
      local.trimmed_quarantine_dataset != ""
      ? "//bigquery.googleapis.com/projects/${local.effective_quality_project_id}/datasets/${local.trimmed_quarantine_dataset}/tables/dataplex_quality_results"
      : ""
    )
  )
}

resource "google_dataplex_datascan" "profile" {
  for_each = var.profile_tables

  project      = var.project_id
  location     = var.region
  data_scan_id = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-${replace(each.key, "_", "-")}-profile"), 0, 63), "-")
  display_name = coalesce(each.value.display_name, "${var.prefix} ${each.value.table_id} profile")
  description  = each.value.description
  labels       = var.labels

  data {
    resource = "//bigquery.googleapis.com/projects/${each.value.project_id}/datasets/${each.value.dataset_id}/tables/${each.value.table_id}"
  }

  execution_spec {
    trigger {
      on_demand {}
    }
  }

  data_profile_spec {
    sampling_percent = each.value.sampling_percent
  }
}

resource "google_dataplex_datascan" "quality" {
  count = var.enable_quality_scan ? 1 : 0

  project      = var.project_id
  location     = var.region
  data_scan_id = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-silver-orders-quality"), 0, 63), "-")
  display_name = "${var.prefix} ${var.quality_target_table_id} quality"
  description  = "Dataplex data quality scan enforcing Silver orders rules."
  labels       = var.labels

  data {
    resource = "//bigquery.googleapis.com/projects/${local.effective_quality_project_id}/datasets/${local.effective_quality_dataset_id}/tables/${var.quality_target_table_id}"
  }

  execution_spec {
    trigger {
      on_demand {}
    }
  }

  data_quality_spec {
    sampling_percent = var.quality_sampling_percent
    row_filter       = "order_date >= DATE('1970-01-01')"

    dynamic "post_scan_actions" {
      for_each = local.effective_quality_results_table != "" ? [local.effective_quality_results_table] : []
      content {
        bigquery_export {
          results_table = post_scan_actions.value
        }
      }
    }

    rules {
      name        = "order-id-not-null"
      description = "Ensure order_id is not null."
      column      = "order_id"
      dimension   = "COMPLETENESS"
      non_null_expectation {}
    }

    rules {
      name        = "order-id-unique"
      description = "Ensure order_id is unique."
      column      = "order_id"
      dimension   = "UNIQUENESS"
      uniqueness_expectation {}
    }

    rules {
      name        = "order-status-valid-set"
      description = "Ensure order_status uses allowed lifecycle values."
      column      = "order_status"
      dimension   = "VALIDITY"
      set_expectation {
        values = ["PAID", "COMPLETED", "SHIPPED", "REFUNDED", "CANCELLED"]
      }
    }

    rules {
      name        = "gross-amount-non-negative"
      description = "Ensure gross_amount is zero or greater."
      column      = "gross_amount"
      dimension   = "VALIDITY"
      range_expectation {
        min_value          = "0"
        strict_min_enabled = false
      }
    }

    rules {
      name        = "net-amount-non-negative"
      description = "Ensure net_amount is zero or greater."
      column      = "net_amount"
      dimension   = "VALIDITY"
      range_expectation {
        min_value          = "0"
        strict_min_enabled = false
      }
    }

    rules {
      name        = "customer-email-not-null"
      description = "Ensure customer_email is not null."
      column      = "customer_email"
      dimension   = "COMPLETENESS"
      non_null_expectation {}
    }

    rules {
      name        = "order-date-not-future"
      description = "Ensure order_date is on or before CURRENT_DATE()."
      dimension   = "VALIDITY"
      sql_assertion {
        sql_statement = "SELECT order_id, order_date FROM $${data()} WHERE order_date > CURRENT_DATE()"
      }
    }
  }

  depends_on = [google_dataplex_datascan.profile]
}
