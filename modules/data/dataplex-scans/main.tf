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
