locals {
  required_apis = var.enable_apis ? toset([
    "datacatalog.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "dataplex.googleapis.com",
  ]) : toset([])

  data_policy_id        = "${replace(var.prefix, "-", "_")}_pii_mask"
  trimmed_env           = var.environment != null ? trimspace(var.environment) : ""
  taxonomy_display_name = local.trimmed_env != "" ? "${var.prefix}-${local.trimmed_env}-pii-taxonomy" : "${var.prefix}-pii-taxonomy"
}

resource "google_project_service" "required" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_data_catalog_taxonomy" "pii" {
  project                = var.project_id
  region                 = var.region
  display_name           = local.taxonomy_display_name
  description            = "Fine-grained PII classification taxonomy."
  activated_policy_types = ["FINE_GRAINED_ACCESS_CONTROL"]

  depends_on = [google_project_service.required]
}

resource "google_data_catalog_policy_tag" "pii_restricted" {
  taxonomy     = google_data_catalog_taxonomy.pii.id
  display_name = "${var.prefix}-pii-restricted"
  description  = "Blocks column reads unless Fine-Grained Reader is granted."
}

resource "google_data_catalog_policy_tag" "pii_masked" {
  taxonomy     = google_data_catalog_taxonomy.pii.id
  display_name = "${var.prefix}-pii-masked"
  description  = "Applies BigQuery data masking for masked reader principals."
}

resource "google_bigquery_datapolicy_data_policy" "pii_mask" {
  project          = var.project_id
  location         = var.region
  data_policy_id   = local.data_policy_id
  policy_tag       = google_data_catalog_policy_tag.pii_masked.name
  data_policy_type = "DATA_MASKING_POLICY"

  data_masking_policy {
    predefined_expression = var.masking_expression
  }

  depends_on = [google_project_service.required]
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "masked_readers" {
  for_each = toset(var.masked_readers)

  project        = var.project_id
  location       = var.region
  data_policy_id = google_bigquery_datapolicy_data_policy.pii_mask.data_policy_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = each.value
}

resource "google_data_catalog_policy_tag_iam_member" "fine_grained_readers_restricted" {
  for_each = toset(var.fine_grained_readers)

  policy_tag = google_data_catalog_policy_tag.pii_restricted.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = each.value
}

resource "google_data_catalog_policy_tag_iam_member" "fine_grained_readers_masked" {
  for_each = toset(var.fine_grained_readers)

  policy_tag = google_data_catalog_policy_tag.pii_masked.name
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = each.value
}

resource "google_dataplex_glossary" "business" {
  count = var.enable_glossary ? 1 : 0

  project      = var.project_id
  location     = var.region
  glossary_id  = "${var.prefix}-business-glossary"
  display_name = "${var.prefix} Business Glossary"
  description  = "Business glossary for governed datasets."
  labels       = var.labels

  depends_on = [google_project_service.required]
}
