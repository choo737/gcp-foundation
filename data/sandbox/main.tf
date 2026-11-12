provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  dataset_prefix         = replace(var.prefix, "-", "_")
  effective_kms_key_name = var.kms_key_name != null ? trimspace(var.kms_key_name) : ""
  use_cmek               = local.effective_kms_key_name != ""

  required_apis = toset([
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",
    "dataform.googleapis.com",
    "secretmanager.googleapis.com",
    "iam.googleapis.com",
  ])

  medallion_datasets = {
    bronze_raw        = "${local.dataset_prefix}_bronze_raw"
    silver_curated    = "${local.dataset_prefix}_silver_curated"
    silver_assertions = "${local.dataset_prefix}_silver_assertions"
    gold_mart         = "${local.dataset_prefix}_gold_mart"
    ops_telemetry     = "${local.dataset_prefix}_ops_telemetry"
  }

  etl_owner_datasets = toset([
    "silver_curated",
    "silver_assertions",
    "gold_mart",
  ])

  git_secret_id = (
    var.git_token_secret_version != ""
    ? regex("^(projects/[^/]+/secrets/[^/]+)/versions/", var.git_token_secret_version)[0]
    : ""
  )
}

resource "google_project_service" "apis" {
  for_each = local.required_apis

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "time_sleep" "api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [google_project_service.apis]
}

resource "google_project_service_identity" "dataform_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "dataform.googleapis.com"

  depends_on = [time_sleep.api_propagation]
}

resource "google_project_service_identity" "dataplex_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "dataplex.googleapis.com"

  depends_on = [time_sleep.api_propagation]
}

resource "time_sleep" "service_identity_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_project_service_identity.dataform_agent,
    google_project_service_identity.dataplex_agent,
  ]
}

resource "google_service_account" "dataform_etl" {
  project      = var.project_id
  account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-etl"), 0, 30), "-")
  display_name = "${var.prefix} Dataform ETL"
  description  = "Dedicated least-privilege service account for Dataform runs."

  depends_on = [time_sleep.api_propagation]
}

module "governance_catalog" {
  source = "../../modules/data/governance-catalog"

  project_id           = var.project_id
  region               = var.region
  prefix               = var.prefix
  masking_expression   = var.masking_expression
  masked_readers       = var.masked_readers
  fine_grained_readers = var.fine_grained_readers
  enable_glossary      = true
  enable_apis          = false
  labels               = var.labels

  depends_on = [time_sleep.api_propagation]
}

module "datasets" {
  for_each = local.medallion_datasets
  source   = "../../modules/data/bigquery-dataset"

  project_id                 = var.project_id
  dataset_id                 = each.value
  region                     = var.region
  description                = "Sandbox Medallion dataset (${each.key})."
  delete_contents_on_destroy = var.delete_contents_on_destroy
  kms_key_name               = local.use_cmek ? local.effective_kms_key_name : null
  readers                    = each.key == "gold_mart" ? var.masked_readers : []
  labels                     = var.labels

  depends_on = [time_sleep.api_propagation]
}

resource "google_service_account_iam_member" "dataform_agent_token_creator" {
  service_account_id = google_service_account.dataform_etl.name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = google_project_service_identity.dataform_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_service_account_iam_member" "dataform_agent_sa_user" {
  service_account_id = google_service_account.dataform_etl.name
  role               = "roles/iam.serviceAccountUser"
  member             = google_project_service_identity.dataform_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_secret_manager_secret_iam_member" "dataform_git_token" {
  count = var.git_token_secret_version != "" ? 1 : 0

  secret_id = local.git_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = google_project_service_identity.dataform_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataform_etl_bronze_viewer" {
  project    = var.project_id
  dataset_id = module.datasets["bronze_raw"].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_service_account.dataform_etl.member
}

resource "google_bigquery_dataset_iam_member" "dataform_etl_owners" {
  for_each = local.etl_owner_datasets

  project    = var.project_id
  dataset_id = module.datasets[each.key].dataset_id
  role       = "roles/bigquery.dataOwner"
  member     = google_service_account.dataform_etl.member
}

resource "google_project_iam_member" "dataform_etl_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.dataform_etl.member
}

resource "google_project_iam_member" "dataform_etl_catalog_viewer" {
  project = var.project_id
  role    = "roles/datacatalog.viewer"
  member  = google_service_account.dataform_etl.member
}

# BigQuery MERGE UPDATE on policy-tagged target columns requires Fine-Grained Reader on dataform_etl only.
resource "google_data_catalog_policy_tag_iam_member" "dataform_etl_masked_reader" {
  policy_tag = module.governance_catalog.pii_masked_policy_tag_id
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = google_service_account.dataform_etl.member
}

resource "google_data_catalog_policy_tag_iam_member" "dataform_etl_restricted_reader" {
  policy_tag = module.governance_catalog.pii_restricted_policy_tag_id
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = google_service_account.dataform_etl.member
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "dataplex_masked_reader" {
  project        = var.project_id
  location       = var.region
  data_policy_id = module.governance_catalog.pii_data_policy_short_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_gold_viewer" {
  project    = var.project_id
  dataset_id = module.datasets["gold_mart"].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

module "dataform_repository" {
  source = "../../modules/data/dataform-repository"

  project_id                = var.project_id
  region                    = var.region
  prefix                    = var.prefix
  repository_name           = "${var.prefix}-medallion"
  service_account_email     = google_service_account.dataform_etl.email
  kms_key_name              = local.effective_kms_key_name
  git_remote_url            = var.medallion_git_url
  git_default_branch        = var.medallion_git_branch
  git_release_commitish     = var.git_release_commitish
  git_token_secret_version  = var.git_token_secret_version
  default_database          = var.project_id
  bronze_project            = var.project_id
  bronze_dataset            = module.datasets["bronze_raw"].dataset_id
  silver_project            = var.project_id
  silver_dataset            = module.datasets["silver_curated"].dataset_id
  gold_project              = var.project_id
  gold_dataset              = module.datasets["gold_mart"].dataset_id
  assertion_schema          = module.datasets["silver_assertions"].dataset_id
  pii_policy_tag            = module.governance_catalog.pii_masked_policy_tag_id
  enable_scheduled_workflow = var.enable_scheduled_workflow
  extra_compilation_vars    = { allow_untagged_pii = "false" }
  labels                    = var.labels

  depends_on = [
    google_service_account_iam_member.dataform_agent_token_creator,
    google_service_account_iam_member.dataform_agent_sa_user,
    google_secret_manager_secret_iam_member.dataform_git_token,
    google_bigquery_dataset_iam_member.dataform_etl_bronze_viewer,
    google_bigquery_dataset_iam_member.dataform_etl_owners,
    google_project_iam_member.dataform_etl_job_user,
    google_project_iam_member.dataform_etl_catalog_viewer,
  ]
}

resource "google_bigquery_table" "pos_orders_cdc" {
  project             = var.project_id
  dataset_id          = module.datasets["bronze_raw"].dataset_id
  table_id            = "pos_orders_cdc"
  description         = "Seeded bronze POS orders table matching the Medallion Dataform source."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  schema = jsonencode([
    {
      name        = "order_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique POS order identifier."
    },
    {
      name        = "order_date"
      type        = "DATE"
      mode        = "NULLABLE"
      description = "Order booking date."
    },
    {
      name        = "store_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Store identifier."
    },
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer identifier."
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer national identity number protected by restricted PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_restricted_policy_tag_id]
      }
    },
    {
      name        = "country_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO country code."
    },
    {
      name        = "currency_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO currency code."
    },
    {
      name        = "gross_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Gross order total before discounts."
    },
    {
      name        = "discount_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Discount amount applied to the order."
    },
    {
      name        = "net_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Net order total after discounts."
    },
    {
      name        = "status"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Order lifecycle status."
    },
    {
      name        = "updated_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Last CDC update timestamp."
    },
    {
      name        = "_metadata_deleted"
      type        = "BOOL"
      mode        = "NULLABLE"
      description = "Optional CDC delete tombstone flag."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_name] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "crm_customers_cdc" {
  project             = var.project_id
  dataset_id          = module.datasets["bronze_raw"].dataset_id
  table_id            = "crm_customers_cdc"
  description         = "Seeded bronze CRM customers table matching the Medallion Dataform source."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  schema = jsonencode([
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique customer identifier."
    },
    {
      name        = "customer_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer full name."
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer national identity number protected by restricted PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_restricted_policy_tag_id]
      }
    },
    {
      name        = "segment"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer business segment."
    },
    {
      name        = "country_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO country code."
    },
    {
      name        = "updated_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Last CDC update timestamp."
    },
    {
      name        = "_metadata_deleted"
      type        = "BOOL"
      mode        = "NULLABLE"
      description = "Optional CDC delete tombstone flag."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_name] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "masked_customers_canary" {
  project             = var.project_id
  dataset_id          = module.datasets["gold_mart"].dataset_id
  table_id            = "masked_customers_canary"
  description         = "Seeded Gold canary table with PII masking policy tags on name and identity number."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  schema = jsonencode([
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique customer identifier."
    },
    {
      name        = "customer_name"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer full name protected by data masking."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer identity number protected by data masking."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "country_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO country code."
    },
    {
      name        = "updated_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Record update timestamp."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_name] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "ops_job_cost_monitor" {
  project             = var.project_id
  dataset_id          = module.datasets["gold_mart"].dataset_id
  table_id            = "ops_job_cost_monitor"
  description         = "Operational BigQuery job cost and slot monitoring view."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = var.labels

  view {
    query          = <<-SQL
      SELECT
        creation_time,
        job_id,
        user_email,
        job_type,
        statement_type,
        state,
        total_bytes_billed,
        total_slot_ms,
        ROUND(total_bytes_billed / POW(1024, 4), 6) AS billed_tib
      FROM `${var.project_id}.region-${lower(var.region)}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
      WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    SQL
    use_legacy_sql = false
  }
}

resource "time_sleep" "dataplex_iam_propagation" {
  create_duration = var.dataplex_iam_propagation_seconds

  depends_on = [
    time_sleep.api_propagation,
    google_bigquery_datapolicy_data_policy_iam_member.dataplex_masked_reader,
    google_bigquery_dataset_iam_member.dataplex_gold_viewer,
    google_bigquery_table.masked_customers_canary,
  ]
}

module "dataplex_scans" {
  source = "../../modules/data/dataplex-scans"

  project_id = var.project_id
  region     = var.region
  prefix     = var.prefix
  labels     = var.labels

  profile_tables = {
    masked_customers_canary = {
      project_id       = var.project_id
      dataset_id       = module.datasets["gold_mart"].dataset_id
      table_id         = google_bigquery_table.masked_customers_canary.table_id
      sampling_percent = 100
      description      = "On-demand data profile scan for masked_customers_canary."
    }
  }

  depends_on = [time_sleep.dataplex_iam_propagation]
}
