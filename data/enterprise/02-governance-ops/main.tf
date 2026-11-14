provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

data "google_project" "core" {
  project_id = var.core_storage_project_id
}

data "google_project" "etl" {
  project_id = var.etl_compute_project_id
}

data "google_project" "gold" {
  project_id = var.primary_gold_project_id
}

data "google_project" "domains" {
  for_each = var.domain_storage_project_ids

  project_id = each.value
}

locals {
  effective_kms_key_id       = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek                   = local.effective_kms_key_id != ""
  dataset_prefix             = replace(var.prefix, "-", "_")
  trimmed_quarantine_dataset = var.quarantine_dataset_id != null ? trimspace(var.quarantine_dataset_id) : ""
  effective_quarantine_ds    = local.trimmed_quarantine_dataset != "" ? local.trimmed_quarantine_dataset : "${local.dataset_prefix}_quarantine"
  effective_vpc_sc_perimeter = var.vpc_sc_perimeter_name != null ? trimspace(var.vpc_sc_perimeter_name) : ""

  effective_data_policy_short_id = (
    var.pii_data_policy_short_id != ""
    ? var.pii_data_policy_short_id
    : "${local.dataset_prefix}_pii_mask"
  )

  git_secret_id = (
    var.git_token_secret_version != ""
    ? regex("^(projects/[^/]+/secrets/[^/]+)/versions/", var.git_token_secret_version)[0]
    : ""
  )

  gold_owner_targets = length(var.domain_storage_project_ids) > 0 ? {
    for domain, proj_id in var.domain_storage_project_ids :
    "gold_${domain}" => {
      project_id = proj_id
      dataset_id = var.domain_gold_dataset_ids[domain]
    }
    } : {
    gold_primary = {
      project_id = var.primary_gold_project_id
      dataset_id = var.primary_gold_dataset_id
    }
  }

  etl_owner_datasets = merge(
    {
      silver = {
        project_id = var.core_storage_project_id
        dataset_id = var.silver_dataset_id
      }
      assertions = {
        project_id = var.core_storage_project_id
        dataset_id = var.assertions_dataset_id
      }
    },
    local.gold_owner_targets,
  )

  domain_project_vars = {
    for d, proj_id in var.domain_storage_project_ids :
    "gold_${d}_project" => proj_id
    if contains(keys(var.domain_gold_dataset_ids), d)
  }

  domain_dataset_vars = {
    for d, ds_id in var.domain_gold_dataset_ids :
    "gold_${d}_dataset" => ds_id
    if contains(keys(var.domain_storage_project_ids), d)
  }

  retail_alias_vars = (
    contains(keys(var.domain_storage_project_ids), "ret") &&
    contains(keys(var.domain_gold_dataset_ids), "ret") &&
    !contains(keys(var.domain_storage_project_ids), "retail")
    ? {
      gold_retail_project = var.domain_storage_project_ids["ret"]
      gold_retail_dataset = var.domain_gold_dataset_ids["ret"]
    }
    : {}
  )

  domain_compilation_vars = merge(
    local.domain_project_vars,
    local.domain_dataset_vars,
    local.retail_alias_vars,
  )

  extra_compilation_vars = merge(
    { allow_untagged_pii = "false" },
    local.domain_compilation_vars,
  )

  vpc_sc_target_projects = distinct(concat(
    [
      "projects/${data.google_project.core.number}",
      "projects/${data.google_project.etl.number}",
      "projects/${data.google_project.gold.number}",
    ],
    [for p in data.google_project.domains : "projects/${p.number}"],
  ))

  dataform_etl_account_id = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-etl"), 0, 30), "-")
  dataform_runtime_identities = [
    "serviceAccount:${local.dataform_etl_account_id}@${var.etl_compute_project_id}.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.etl.number}@gcp-sa-dataform.iam.gserviceaccount.com",
    "serviceAccount:service-${data.google_project.gold.number}@gcp-sa-dataplex.iam.gserviceaccount.com",
  ]

  env_labels = merge(var.labels, { environment = var.environment })
}

resource "google_project_service_identity" "dataform_agent" {
  provider = google-beta
  project  = var.etl_compute_project_id
  service  = "dataform.googleapis.com"
}

resource "google_project_service_identity" "dataplex_agent" {
  provider = google-beta
  project  = var.primary_gold_project_id
  service  = "dataplex.googleapis.com"
}

resource "time_sleep" "service_identity_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_project_service_identity.dataform_agent,
    google_project_service_identity.dataplex_agent,
  ]
}

resource "google_service_account" "dataform_etl" {
  project      = var.etl_compute_project_id
  account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-etl"), 0, 30), "-")
  display_name = "${var.prefix} Dataform ETL"
  description  = "Dedicated least-privilege service account for Dataform workflow runs."
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
  project    = var.core_storage_project_id
  dataset_id = var.bronze_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_service_account.dataform_etl.member
}

resource "google_bigquery_dataset_iam_member" "dataform_etl_runner" {
  for_each = local.etl_owner_datasets

  project    = each.value.project_id
  dataset_id = each.value.dataset_id
  role       = lookup(var.dataform_custom_role_ids, each.value.project_id, "projects/${each.value.project_id}/roles/dataform_pipeline_runner")
  member     = google_service_account.dataform_etl.member
}

resource "google_project_iam_member" "dataform_etl_job_user" {
  project = var.etl_compute_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.dataform_etl.member
}

resource "google_project_iam_member" "dataform_etl_catalog_viewer" {
  project = var.governance_project_id
  role    = "roles/datacatalog.viewer"
  member  = google_service_account.dataform_etl.member
}

# BigQuery MERGE UPDATE on policy-tagged target columns requires Fine-Grained Reader on dataform_etl only.
resource "google_data_catalog_policy_tag_iam_member" "dataform_etl_masked_reader" {
  policy_tag = var.pii_masked_policy_tag_id
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = google_service_account.dataform_etl.member
}

resource "google_data_catalog_policy_tag_iam_member" "dataform_etl_restricted_reader" {
  policy_tag = var.pii_restricted_policy_tag_id
  role       = "roles/datacatalog.categoryFineGrainedReader"
  member     = google_service_account.dataform_etl.member
}

resource "google_bigquery_datapolicy_data_policy_iam_member" "dataplex_masked_reader" {
  project        = var.governance_project_id
  location       = var.region
  data_policy_id = local.effective_data_policy_short_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_gold_viewer" {
  project    = var.primary_gold_project_id
  dataset_id = var.primary_gold_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_domain_gold_viewer" {
  for_each = {
    for domain, proj_id in var.domain_storage_project_ids :
    domain => {
      project_id = proj_id
      dataset_id = var.domain_gold_dataset_ids[domain]
    }
    if contains(keys(var.domain_gold_dataset_ids), domain) && proj_id != var.primary_gold_project_id
  }

  project    = each.value.project_id
  dataset_id = each.value.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_silver_viewer" {
  project    = var.core_storage_project_id
  dataset_id = var.silver_dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_bigquery_dataset_iam_member" "dataplex_quarantine_editor" {
  count = (var.enable_quality_scan || length(var.additional_quality_scans) > 0) && local.effective_quarantine_ds != "" ? 1 : 0

  project    = var.core_storage_project_id
  dataset_id = local.effective_quarantine_ds
  role       = "roles/bigquery.dataEditor"
  member     = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_project_iam_member" "dataplex_agent_job_user" {
  project = var.primary_gold_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_project_iam_member" "dataplex_service_agent" {
  project = var.primary_gold_project_id
  role    = "roles/dataplex.serviceAgent"
  member  = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

data "google_bigquery_default_service_account" "etl" {
  count = local.use_cmek ? 1 : 0

  project = var.etl_compute_project_id
}

resource "google_kms_crypto_key_iam_member" "dataform_agent_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.dataform_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_kms_crypto_key_iam_member" "dataplex_agent_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.dataplex_agent.member

  depends_on = [time_sleep.service_identity_propagation]
}

resource "google_kms_crypto_key_iam_member" "dataform_etl_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_service_account.dataform_etl.member
}

resource "google_kms_crypto_key_iam_member" "bq_etl_ops_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.etl[0].member
}

resource "time_sleep" "iam_and_kms_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_service_account_iam_member.dataform_agent_token_creator,
    google_service_account_iam_member.dataform_agent_sa_user,
    google_secret_manager_secret_iam_member.dataform_git_token,
    google_bigquery_dataset_iam_member.dataform_etl_bronze_viewer,
    google_bigquery_dataset_iam_member.dataform_etl_runner,
    google_project_iam_member.dataform_etl_job_user,
    google_project_iam_member.dataform_etl_catalog_viewer,
    google_data_catalog_policy_tag_iam_member.dataform_etl_masked_reader,
    google_data_catalog_policy_tag_iam_member.dataform_etl_restricted_reader,
    google_bigquery_datapolicy_data_policy_iam_member.dataplex_masked_reader,
    google_kms_crypto_key_iam_member.dataform_agent_cmek,
    google_kms_crypto_key_iam_member.dataplex_agent_cmek,
    google_kms_crypto_key_iam_member.dataform_etl_cmek,
    google_kms_crypto_key_iam_member.bq_etl_ops_cmek,
  ]
}

module "dataform_repository" {
  source = "../../../modules/data/dataform-repository"

  project_id                = var.etl_compute_project_id
  region                    = var.region
  prefix                    = var.prefix
  environment               = var.environment
  repository_name           = "${var.prefix}-medallion"
  service_account_email     = google_service_account.dataform_etl.email
  kms_key_name              = local.effective_kms_key_id
  git_remote_url            = var.medallion_git_url
  git_default_branch        = var.medallion_git_branch
  git_release_commitish     = var.git_release_commitish
  git_token_secret_version  = var.git_token_secret_version
  default_database          = var.core_storage_project_id
  bronze_project            = var.core_storage_project_id
  bronze_dataset            = var.bronze_dataset_id
  silver_project            = var.core_storage_project_id
  silver_dataset            = var.silver_dataset_id
  gold_project              = var.primary_gold_project_id
  gold_dataset              = var.primary_gold_dataset_id
  assertion_schema          = var.assertions_dataset_id
  pii_policy_tag            = var.pii_masked_policy_tag_id
  pii_masked_policy_tag     = var.pii_masked_policy_tag_id
  pii_restricted_policy_tag = var.pii_restricted_policy_tag_id
  enable_scheduled_workflow = var.enable_scheduled_workflow
  extra_compilation_vars    = local.extra_compilation_vars
  labels                    = local.env_labels

  depends_on = [time_sleep.iam_and_kms_propagation]
}

resource "google_bigquery_table" "pos_orders_cdc" {
  project             = var.core_storage_project_id
  dataset_id          = var.bronze_dataset_id
  table_id            = "pos_orders_cdc"
  description         = "Seeded bronze POS orders CDC table matching the Medallion Dataform source."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = local.env_labels

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
        names = [var.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer national identity number protected by restricted PII tag."
      policyTags = {
        names = [var.pii_restricted_policy_tag_id]
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
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "crm_customers_cdc" {
  project             = var.core_storage_project_id
  dataset_id          = var.bronze_dataset_id
  table_id            = "crm_customers_cdc"
  description         = "Seeded bronze CRM customers CDC table matching the Medallion Dataform source."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = local.env_labels

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
        names = [var.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_email"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer email address protected by masked PII tag."
      policyTags = {
        names = [var.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer national identity number protected by restricted PII tag."
      policyTags = {
        names = [var.pii_restricted_policy_tag_id]
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
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_table" "fct_orders_seed" {
  project                  = var.core_storage_project_id
  dataset_id               = var.silver_dataset_id
  table_id                 = var.quality_target_table_id
  description              = "Pre-seeded Silver fct_orders table enabling Day-1 Dataplex quality scan creation."
  deletion_protection      = !var.delete_contents_on_destroy
  require_partition_filter = true
  clustering               = ["customer_id", "currency_code"]
  labels                   = local.env_labels

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
        names = [var.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer national identity number protected by restricted PII tag."
      policyTags = {
        names = [var.pii_restricted_policy_tag_id]
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
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }

  lifecycle {
    ignore_changes = [schema, description, labels]
  }
}

resource "google_bigquery_table" "masked_customers_canary" {
  project             = var.primary_gold_project_id
  dataset_id          = var.primary_gold_dataset_id
  table_id            = "masked_customers_canary"
  description         = "Seeded Gold canary table with PII masking policy tags on name and identity number."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = local.env_labels

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
        names = [var.pii_masked_policy_tag_id]
      }
    },
    {
      name        = "customer_ic_number"
      type        = "STRING"
      mode        = "NULLABLE"
      description = "Customer identity number protected by data masking."
      policyTags = {
        names = [var.pii_masked_policy_tag_id]
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
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = encryption_configuration.value
    }
  }
}

resource "google_bigquery_dataset" "ops_telemetry" {
  project                    = var.etl_compute_project_id
  dataset_id                 = "${local.dataset_prefix}_ops_telemetry"
  friendly_name              = "${var.prefix} Ops Telemetry"
  description                = "Operational BigQuery job cost and slot telemetry dataset in data-etl."
  location                   = var.region
  max_time_travel_hours      = 168
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = local.env_labels

  dynamic "default_encryption_configuration" {
    for_each = local.use_cmek ? [local.effective_kms_key_id] : []
    content {
      kms_key_name = default_encryption_configuration.value
    }
  }

  depends_on = [time_sleep.iam_and_kms_propagation]
}

resource "google_bigquery_table" "ops_job_cost_monitor" {
  project             = var.etl_compute_project_id
  dataset_id          = google_bigquery_dataset.ops_telemetry.dataset_id
  table_id            = "ops_job_cost_monitor"
  description         = "Operational BigQuery job cost and slot monitoring view over ETL compute."
  deletion_protection = !var.delete_contents_on_destroy
  labels              = local.env_labels

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
      FROM `${var.etl_compute_project_id}.region-${lower(var.region)}`.INFORMATION_SCHEMA.JOBS_BY_PROJECT
      WHERE creation_time >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
    SQL
    use_legacy_sql = false
  }
}

resource "time_sleep" "dataplex_iam_propagation" {
  create_duration = var.dataplex_iam_propagation_seconds

  depends_on = [
    time_sleep.iam_and_kms_propagation,
    google_bigquery_datapolicy_data_policy_iam_member.dataplex_masked_reader,
    google_bigquery_dataset_iam_member.dataplex_gold_viewer,
    google_bigquery_dataset_iam_member.dataplex_domain_gold_viewer,
    google_bigquery_dataset_iam_member.dataplex_silver_viewer,
    google_bigquery_dataset_iam_member.dataplex_quarantine_editor,
    google_project_iam_member.dataplex_agent_job_user,
    google_project_iam_member.dataplex_service_agent,
    google_bigquery_table.masked_customers_canary,
    google_bigquery_table.fct_orders_seed,
  ]
}

module "dataplex_scans" {
  source = "../../../modules/data/dataplex-scans"

  project_id                = var.primary_gold_project_id
  region                    = var.region
  prefix                    = var.prefix
  enable_quality_scan       = var.enable_quality_scan
  quality_target_project_id = var.core_storage_project_id
  quality_target_dataset_id = var.silver_dataset_id
  quality_target_table_id   = var.quality_target_table_id
  quarantine_dataset_id     = local.effective_quarantine_ds
  quality_results_table     = var.quality_results_table
  labels                    = local.env_labels

  profile_tables = {
    masked_customers_canary = {
      project_id       = var.primary_gold_project_id
      dataset_id       = var.primary_gold_dataset_id
      table_id         = google_bigquery_table.masked_customers_canary.table_id
      sampling_percent = 100
      description      = "On-demand data profile scan for masked_customers_canary."
    }
  }

  depends_on = [time_sleep.dataplex_iam_propagation]
}

module "additional_quality_scans" {
  for_each = var.additional_quality_scans
  source   = "../../../modules/data/dataplex-scans"

  project_id                = var.primary_gold_project_id
  region                    = var.region
  prefix                    = var.prefix
  enable_quality_scan       = true
  quality_scan_id           = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-${replace(each.key, "_", "-")}-quality"), 0, 63), "-")
  quality_target_project_id = each.value.project_id != "" ? each.value.project_id : var.core_storage_project_id
  quality_target_dataset_id = each.value.dataset_id != "" ? each.value.dataset_id : var.silver_dataset_id
  quality_target_table_id   = each.value.table_id
  quality_row_filter        = each.value.row_filter
  quality_sampling_percent  = each.value.sampling_percent
  quality_schedule_cron     = each.value.schedule_cron
  quarantine_project_id     = var.core_storage_project_id
  quarantine_dataset_id     = local.effective_quarantine_ds
  quality_results_table     = each.value.results_table
  quality_rules             = each.value.rules
  labels                    = local.env_labels

  depends_on = [time_sleep.dataplex_iam_propagation]
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "dataform_runtime" {
  count = local.effective_vpc_sc_perimeter != "" && !var.enforce_vpc_sc ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-dataform-ingress"

  ingress_from {
    identities = local.dataform_runtime_identities
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.vpc_sc_target_projects
    operations {
      service_name = "*"
    }
  }

  depends_on = [
    google_service_account.dataform_etl,
    time_sleep.service_identity_propagation,
  ]
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "dataform_runtime" {
  count = local.effective_vpc_sc_perimeter != "" && var.enforce_vpc_sc ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-dataform-ingress"

  ingress_from {
    identities = local.dataform_runtime_identities
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.vpc_sc_target_projects
    operations {
      service_name = "*"
    }
  }

  depends_on = [
    google_service_account.dataform_etl,
    time_sleep.service_identity_propagation,
  ]
}
