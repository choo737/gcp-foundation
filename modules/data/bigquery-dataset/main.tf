locals {
  effective_kms_key_name = var.kms_key_name != null ? trimspace(var.kms_key_name) : ""
}

resource "google_bigquery_dataset" "this" {
  project                         = var.project_id
  dataset_id                      = var.dataset_id
  friendly_name                   = coalesce(var.friendly_name, var.dataset_id)
  description                     = var.description
  location                        = var.region
  max_time_travel_hours           = var.max_time_travel_hours
  default_partition_expiration_ms = var.default_partition_expiration_ms
  default_table_expiration_ms     = var.default_table_expiration_ms
  delete_contents_on_destroy      = var.delete_contents_on_destroy
  labels                          = var.labels

  dynamic "default_encryption_configuration" {
    for_each = local.effective_kms_key_name != "" ? [local.effective_kms_key_name] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }
}

resource "google_bigquery_dataset_iam_member" "readers" {
  for_each = toset(var.readers)

  project    = var.project_id
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

resource "google_bigquery_dataset_iam_member" "editors" {
  for_each = toset(var.editors)

  project    = var.project_id
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = each.value
}
