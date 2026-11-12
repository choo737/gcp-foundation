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
  trimmed_batch_sa       = var.batch_loader_sa_email != null ? trimspace(var.batch_loader_sa_email) : ""
  batch_loader_member    = local.trimmed_batch_sa != "" ? (startswith(local.trimmed_batch_sa, "serviceAccount:") ? local.trimmed_batch_sa : "serviceAccount:${local.trimmed_batch_sa}") : ""

  required_apis = toset([
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "datacatalog.googleapis.com",
    "dataplex.googleapis.com",
    "dataform.googleapis.com",
    "run.googleapis.com",
    "secretmanager.googleapis.com",
    "storage.googleapis.com",
    "iam.googleapis.com",
  ])

  medallion_datasets = {
    bronze_raw = {
      dataset_id                      = "${local.dataset_prefix}_bronze_raw"
      default_table_expiration_ms     = null
      default_partition_expiration_ms = null
    }
    silver_curated = {
      dataset_id                      = "${local.dataset_prefix}_silver_curated"
      default_table_expiration_ms     = null
      default_partition_expiration_ms = null
    }
    silver_assertions = {
      dataset_id                      = "${local.dataset_prefix}_silver_assertions"
      default_table_expiration_ms     = var.ephemeral_table_expiration_ms
      default_partition_expiration_ms = var.ephemeral_partition_expiration_ms
    }
    gold_mart = {
      dataset_id                      = "${local.dataset_prefix}_gold_mart"
      default_table_expiration_ms     = null
      default_partition_expiration_ms = null
    }
    quarantine = {
      dataset_id                      = "${local.dataset_prefix}_quarantine"
      default_table_expiration_ms     = var.ephemeral_table_expiration_ms
      default_partition_expiration_ms = var.ephemeral_partition_expiration_ms
    }
    ops_telemetry = {
      dataset_id                      = "${local.dataset_prefix}_ops_telemetry"
      default_table_expiration_ms     = null
      default_partition_expiration_ms = null
    }
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

  dataform_role_permissions = [
    "bigquery.tables.create",
    "bigquery.tables.delete",
    "bigquery.tables.export",
    "bigquery.tables.get",
    "bigquery.tables.getData",
    "bigquery.tables.getIamPolicy",
    "bigquery.tables.list",
    "bigquery.tables.setCategory",
    "bigquery.tables.update",
    "bigquery.tables.updateData",
    "bigquery.datasets.get",
    "bigquery.datasets.getIamPolicy",
    "bigquery.routines.create",
    "bigquery.routines.delete",
    "bigquery.routines.get",
    "bigquery.routines.list",
    "bigquery.routines.update",
  ]
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

resource "google_project_service_identity" "artifactregistry_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "artifactregistry.googleapis.com"

  depends_on = [time_sleep.api_propagation]
}

resource "google_project_service_identity" "cloudrun_agent" {
  provider = google-beta
  project  = var.project_id
  service  = "run.googleapis.com"

  depends_on = [time_sleep.api_propagation]
}

resource "time_sleep" "service_identity_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_project_service_identity.dataform_agent,
    google_project_service_identity.dataplex_agent,
    google_project_service_identity.artifactregistry_agent,
    google_project_service_identity.cloudrun_agent,
  ]
}

resource "google_service_account" "dataform_etl" {
  project      = var.project_id
  account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-etl"), 0, 30), "-")
  display_name = "${var.prefix} Dataform ETL"
  description  = "Dedicated least-privilege service account for Dataform runs."

  depends_on = [time_sleep.api_propagation]
}

resource "google_project_iam_custom_role" "dataform_pipeline_runner" {
  project     = var.project_id
  role_id     = "dataform_pipeline_runner"
  title       = "Dataform Pipeline Runner"
  description = "Least-privilege table and routine role without dataset update or delete."
  permissions = local.dataform_role_permissions

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

resource "google_storage_bucket" "landing" {
  project                     = var.project_id
  name                        = "${var.project_id}-landing"
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
      age            = 90
      matches_prefix = ["incoming/"]
    }
    action {
      type = "Delete"
    }
  }

  dynamic "encryption" {
    for_each = local.use_cmek ? [local.effective_kms_key_name] : []
    content {
      default_kms_key_name = encryption.value
    }
  }

  depends_on = [time_sleep.api_propagation]
}

resource "google_artifact_registry_repository" "ingestion" {
  project       = var.project_id
  location      = var.region
  repository_id = "${var.prefix}-ingestion"
  description   = "Container registry for sandbox ingestion jobs."
  format        = "DOCKER"
  kms_key_name  = local.use_cmek ? local.effective_kms_key_name : null
  labels        = var.labels

  docker_config {
    immutable_tags = var.immutable_image_tags
  }

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ingestion.name
  role       = "roles/artifactregistry.reader"
  member     = google_project_service_identity.cloudrun_agent.member
}

resource "google_artifact_registry_repository_iam_member" "batch_loader_reader" {
  count = local.batch_loader_member != "" ? 1 : 0

  project    = var.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ingestion.name
  role       = "roles/artifactregistry.reader"
  member     = local.batch_loader_member
}

module "datasets" {
  for_each = local.medallion_datasets
  source   = "../../modules/data/bigquery-dataset"

  project_id                      = var.project_id
  dataset_id                      = each.value.dataset_id
  region                          = var.region
  description                     = "Sandbox Medallion dataset (${each.key})."
  default_table_expiration_ms     = each.value.default_table_expiration_ms
  default_partition_expiration_ms = each.value.default_partition_expiration_ms
  delete_contents_on_destroy      = var.delete_contents_on_destroy
  kms_key_name                    = local.use_cmek ? local.effective_kms_key_name : null
  readers                         = each.key == "gold_mart" ? var.masked_readers : []
  labels                          = var.labels

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

resource "google_bigquery_dataset_iam_member" "dataform_etl_runner" {
  for_each = local.etl_owner_datasets

  project    = var.project_id
  dataset_id = module.datasets[each.key].dataset_id
  role       = google_project_iam_custom_role.dataform_pipeline_runner.id
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

resource "google_bigquery_dataset_iam_member" "dataplex_silver_viewer" {
  project    = var.project_id
  dataset_id = module.datasets["silver_curated"].dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_quarantine_editor" {
  project    = var.project_id
  dataset_id = module.datasets["quarantine"].dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_project_iam_member" "dataplex_agent_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

module "dataform_repository" {
  source = "../../modules/data/dataform-repository"

  project_id                = var.project_id
  region                    = var.region
  prefix                    = var.prefix
  environment               = var.environment
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
  pii_masked_policy_tag     = module.governance_catalog.pii_masked_policy_tag_id
  pii_restricted_policy_tag = module.governance_catalog.pii_restricted_policy_tag_id
  enable_scheduled_workflow = var.enable_scheduled_workflow
  extra_compilation_vars    = { allow_untagged_pii = "false" }
  labels                    = var.labels

  depends_on = [
    google_service_account_iam_member.dataform_agent_token_creator,
    google_service_account_iam_member.dataform_agent_sa_user,
    google_secret_manager_secret_iam_member.dataform_git_token,
    google_bigquery_dataset_iam_member.dataform_etl_bronze_viewer,
    google_bigquery_dataset_iam_member.dataform_etl_runner,
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

  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  schema = jsonencode([
    {
      name        = "order_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique POS order identifier."
    },
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer identifier."
    },
    {
      name        = "customer_email"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer email address protected by masked PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
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
      name        = "store_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Store identifier."
    },
    {
      name        = "order_status"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Order lifecycle status."
    },
    {
      name        = "order_date"
      type        = "DATE"
      mode        = "NULLABLE"
      description = "Order booking date."
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
      name        = "tax_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Tax amount applied to the order."
    },
    {
      name        = "net_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Net order total after discounts and taxes."
    },
    {
      name        = "currency_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO currency code."
    },
    {
      name        = "country_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO country code."
    },
    {
      name        = "_ingested_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "CDC ingestion timestamp."
    },
    {
      name        = "_cdc_sequence_num"
      type        = "INT64"
      mode        = "NULLABLE"
      description = "Monotonic CDC sequence number."
    },
    {
      name        = "_op_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "CDC operation type (INSERT, UPDATE, DELETE)."
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

  time_partitioning {
    type  = "DAY"
    field = "_ingested_at"
  }

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
      description = "Customer full name protected by masked PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_email"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer email address protected by masked PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
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
      name        = "_ingested_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Ingestion timestamp used for daily partitioning."
    },
    {
      name        = "_cdc_sequence_num"
      type        = "INT64"
      mode        = "NULLABLE"
      description = "Monotonic CDC sequence number."
    },
    {
      name        = "_op_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "CDC operation type (INSERT, UPDATE, DELETE)."
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

resource "google_bigquery_table" "fct_orders_seed" {
  project                  = var.project_id
  dataset_id               = module.datasets["silver_curated"].dataset_id
  table_id                 = var.quality_target_table_id
  description              = "Pre-seeded Silver fct_orders table enabling Day-1 Dataplex quality scan creation."
  deletion_protection      = !var.delete_contents_on_destroy
  require_partition_filter = true
  clustering               = ["customer_id", "currency_code"]
  labels                   = var.labels

  time_partitioning {
    type  = "DAY"
    field = "order_date"
  }

  schema = jsonencode([
    {
      name        = "order_id"
      type        = "STRING"
      mode        = "REQUIRED"
      description = "Unique POS order identifier."
    },
    {
      name        = "customer_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer identifier."
    },
    {
      name        = "customer_email"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer email address protected by masked PII tag."
      policyTags = {
        names = [module.governance_catalog.pii_masked_policy_tag_id]
      }
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
      name        = "store_id"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Store identifier."
    },
    {
      name        = "order_status"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Order lifecycle status."
    },
    {
      name        = "order_date"
      type        = "DATE"
      mode        = "NULLABLE"
      description = "Order booking date."
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
      name        = "tax_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Tax amount applied to the order."
    },
    {
      name        = "net_amount"
      type        = "NUMERIC"
      mode        = "NULLABLE"
      description = "Net order total after discounts and taxes."
    },
    {
      name        = "currency_code"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "ISO currency code."
    },
    {
      name        = "_ingested_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "CDC ingestion timestamp."
    },
    {
      name        = "_cdc_sequence_num"
      type        = "INT64"
      mode        = "NULLABLE"
      description = "Monotonic CDC sequence number."
    },
    {
      name        = "_op_type"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "CDC operation type."
    },
    {
      name        = "ingested_at"
      type        = "TIMESTAMP"
      mode        = "NULLABLE"
      description = "Silver ingestion timestamp."
    },
    {
      name        = "record_hash"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "SHA-256 hash of key order attributes."
    }
  ])

  dynamic "encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_name] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }

  lifecycle {
    ignore_changes = [schema, description, labels]
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
    google_bigquery_dataset_iam_member.dataplex_silver_viewer,
    google_bigquery_dataset_iam_member.dataplex_quarantine_editor,
    google_project_iam_member.dataplex_agent_job_user,
    google_bigquery_table.masked_customers_canary,
    google_bigquery_table.fct_orders_seed,
  ]
}

module "dataplex_scans" {
  source = "../../modules/data/dataplex-scans"

  project_id                = var.project_id
  region                    = var.region
  prefix                    = var.prefix
  enable_quality_scan       = var.enable_quality_scan
  quality_target_project_id = var.project_id
  quality_target_dataset_id = module.datasets["silver_curated"].dataset_id
  quality_target_table_id   = var.quality_target_table_id
  quarantine_dataset_id     = module.datasets["quarantine"].dataset_id
  quality_results_table     = var.quality_results_table
  labels                    = var.labels

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
