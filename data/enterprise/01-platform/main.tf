provider "google" {
  region = var.region
}

resource "terraform_data" "validate_primary_domain" {
  lifecycle {
    precondition {
      condition     = contains(var.domain_marts, var.primary_domain)
      error_message = "primary_domain must be included in domain_marts."
    }
  }
}

locals {
  project_prefix       = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  dataset_prefix       = replace(var.prefix, "-", "_")
  parent_folder        = "folders/${replace(var.data_folder_id, "folders/", "")}"
  effective_kms_key_id = coalesce(var.kms_key_id, "")
  use_cmek             = local.effective_kms_key_id != ""
  all_masked_readers   = distinct(concat(var.masked_readers, var.bi_analysts))

  dp_gov_project_id     = "${local.project_prefix}-dp-gov"
  dp_st_core_project_id = "${local.project_prefix}-dp-st-core"
  dp_cp_etl_project_id  = "${local.project_prefix}-dp-cp-etl"
  dp_cp_bi_project_id   = "${local.project_prefix}-dp-cp-bi"

  core_datasets = {
    bronze_raw        = "${local.dataset_prefix}_bronze_raw"
    silver_curated    = "${local.dataset_prefix}_silver_curated"
    silver_assertions = "${local.dataset_prefix}_silver_assertions"
  }
}

resource "google_folder" "storage" {
  display_name        = "storage"
  parent              = local.parent_folder
  deletion_protection = var.deletion_protection
}

resource "google_folder" "compute" {
  display_name        = "compute"
  parent              = local.parent_folder
  deletion_protection = var.deletion_protection
}

module "dp_gov" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.dp_gov_project_id
  folder_id       = google_folder.storage.name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "datacatalog.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "dataplex.googleapis.com",
  ]
}

module "dp_st_core" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.dp_st_core_project_id
  folder_id       = google_folder.storage.name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "dataplex.googleapis.com",
  ]
}

module "dp_st_domain" {
  for_each = var.domain_marts
  source   = "../../../modules/foundation/project-factory"

  project_id      = "${local.project_prefix}-dp-st-${each.key}"
  folder_id       = google_folder.storage.name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "bigquery.googleapis.com",
    "dataplex.googleapis.com",
  ]
}

module "dp_cp_etl" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.dp_cp_etl_project_id
  folder_id       = google_folder.compute.name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "bigquery.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "dataform.googleapis.com",
    "secretmanager.googleapis.com",
    "dataplex.googleapis.com",
    "iam.googleapis.com",
  ]
}

module "dp_cp_bi" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.dp_cp_bi_project_id
  folder_id       = google_folder.compute.name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "bigquery.googleapis.com",
  ]
}

resource "time_sleep" "gov_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.dp_gov]
}

resource "time_sleep" "storage_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    module.dp_st_core,
    module.dp_st_domain,
  ]
}

resource "time_sleep" "compute_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    module.dp_cp_etl,
    module.dp_cp_bi,
  ]
}

data "google_storage_project_service_account" "core" {
  count = local.use_cmek ? 1 : 0

  project    = module.dp_st_core.project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "core" {
  count = local.use_cmek ? 1 : 0

  project    = module.dp_st_core.project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "domain" {
  for_each = local.use_cmek ? var.domain_marts : toset([])

  project    = module.dp_st_domain[each.key].project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "etl" {
  count = local.use_cmek ? 1 : 0

  project    = module.dp_cp_etl.project_id
  depends_on = [time_sleep.compute_api_propagation]
}

data "google_bigquery_default_service_account" "bi" {
  count = local.use_cmek ? 1 : 0

  project    = module.dp_cp_bi.project_id
  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_kms_crypto_key_iam_member" "storage_core_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.core[0].email_address}"
}

resource "google_kms_crypto_key_iam_member" "bq_core_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.core[0].member
}

resource "google_kms_crypto_key_iam_member" "bq_domain_cmek" {
  for_each = local.use_cmek ? var.domain_marts : toset([])

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.domain[each.key].member
}

resource "google_kms_crypto_key_iam_member" "bq_etl_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.etl[0].member
}

resource "google_kms_crypto_key_iam_member" "bq_bi_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.bi[0].member
}

resource "time_sleep" "cmek_iam_propagation" {
  count = local.use_cmek ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_kms_crypto_key_iam_member.storage_core_cmek,
    google_kms_crypto_key_iam_member.bq_core_cmek,
    google_kms_crypto_key_iam_member.bq_domain_cmek,
    google_kms_crypto_key_iam_member.bq_etl_cmek,
    google_kms_crypto_key_iam_member.bq_bi_cmek,
  ]
}

module "governance_catalog" {
  source = "../../../modules/data/governance-catalog"

  project_id           = module.dp_gov.project_id
  region               = var.region
  prefix               = var.prefix
  masking_expression   = var.masking_expression
  masked_readers       = local.all_masked_readers
  fine_grained_readers = var.fine_grained_readers
  enable_glossary      = true
  enable_apis          = false
  labels               = var.labels

  depends_on = [time_sleep.gov_api_propagation]
}

resource "google_storage_bucket" "landing" {
  project                     = module.dp_st_core.project_id
  name                        = "${module.dp_st_core.project_id}-landing"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.delete_contents_on_destroy
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      age = 90
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "core_datasets" {
  for_each = local.core_datasets
  source   = "../../../modules/data/bigquery-dataset"

  project_id                 = module.dp_st_core.project_id
  dataset_id                 = each.value
  region                     = var.region
  description                = "Enterprise core storage dataset (${each.key})."
  delete_contents_on_destroy = var.delete_contents_on_destroy
  kms_key_name               = local.use_cmek ? local.effective_kms_key_id : null
  readers                    = []
  labels                     = var.labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "domain_gold_mart" {
  for_each = var.domain_marts
  source   = "../../../modules/data/bigquery-dataset"

  project_id                 = module.dp_st_domain[each.key].project_id
  dataset_id                 = "${local.dataset_prefix}_gold_mart"
  region                     = var.region
  description                = "Enterprise Gold mart dataset for domain ${each.key}."
  delete_contents_on_destroy = var.delete_contents_on_destroy
  kms_key_name               = local.use_cmek ? local.effective_kms_key_id : null
  readers                    = var.bi_analysts
  labels                     = var.labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "reservations" {
  count  = var.enable_reservations ? 1 : 0
  source = "../../../modules/data/bigquery-reservations"

  project_id = module.dp_cp_etl.project_id
  region     = var.region
  prefix     = var.prefix
  labels     = var.labels

  reservations = {
    etl = {
      edition           = "ENTERPRISE"
      slot_capacity     = 0
      ignore_idle_slots = false
      max_slots         = 100
    }
    bi = {
      edition           = "ENTERPRISE"
      slot_capacity     = 0
      ignore_idle_slots = false
      max_slots         = 100
    }
    adhoc = {
      edition           = "ENTERPRISE"
      slot_capacity     = 0
      ignore_idle_slots = false
      max_slots         = 100
    }
  }

  assignments = {
    (local.dp_cp_etl_project_id) = "etl"
    (local.dp_cp_bi_project_id)  = "bi"
  }

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_iam_member" "bi_analysts_job_user" {
  for_each = toset(var.bi_analysts)

  project = module.dp_cp_bi.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value

  depends_on = [time_sleep.compute_api_propagation]
}
