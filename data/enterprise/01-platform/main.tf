provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

locals {
  project_prefix              = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  dataset_prefix              = replace(var.prefix, "-", "_")
  trimmed_data_folder_id      = var.data_folder_id != null ? trimspace(var.data_folder_id) : ""
  trimmed_storage_folder_id   = var.storage_folder_id != null ? trimspace(var.storage_folder_id) : ""
  trimmed_compute_folder_id   = var.compute_folder_id != null ? trimspace(var.compute_folder_id) : ""
  env_storage_folder_id       = lookup(var.environment_storage_folder_ids, var.environment, "")
  env_compute_folder_id       = lookup(var.environment_compute_folder_ids, var.environment, "")
  resolved_storage_folder_id  = local.env_storage_folder_id != "" ? local.env_storage_folder_id : local.trimmed_storage_folder_id
  resolved_compute_folder_id  = local.env_compute_folder_id != "" ? local.env_compute_folder_id : local.trimmed_compute_folder_id
  create_subfolders           = local.resolved_storage_folder_id == "" || local.resolved_compute_folder_id == ""
  parent_folder               = local.trimmed_data_folder_id != "" ? "folders/${replace(local.trimmed_data_folder_id, "folders/", "")}" : ""
  effective_storage_folder_id = local.resolved_storage_folder_id != "" ? local.resolved_storage_folder_id : try(google_folder.storage[0].name, "")
  effective_compute_folder_id = local.resolved_compute_folder_id != "" ? local.resolved_compute_folder_id : try(google_folder.compute[0].name, "")

  effective_kms_key_id       = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek                   = local.effective_kms_key_id != ""
  trimmed_dr_region          = var.dr_region != null ? trimspace(var.dr_region) : ""
  effective_dr_kms_key_id    = var.dr_kms_key_id != null ? trimspace(var.dr_kms_key_id) : ""
  create_dr_datasets         = var.enable_dr_datasets && local.trimmed_dr_region != ""
  effective_shared_vpc_host  = var.shared_vpc_host_project_id != null ? trimspace(var.shared_vpc_host_project_id) : ""
  effective_vpc_sc_perimeter = var.vpc_sc_perimeter_name != null ? trimspace(var.vpc_sc_perimeter_name) : ""
  trimmed_batch_loader_sa    = var.batch_loader_sa_email != null ? trimspace(var.batch_loader_sa_email) : ""
  trimmed_dataform_sa        = var.dataform_sa_email != null ? trimspace(var.dataform_sa_email) : ""
  trimmed_bi_group           = var.bi_analysts_group != null ? trimspace(var.bi_analysts_group) : ""
  trimmed_de_group           = var.data_engineers_group != null ? trimspace(var.data_engineers_group) : ""
  trimmed_stewards_group     = var.governance_stewards_group != null ? trimspace(var.governance_stewards_group) : ""
  trimmed_break_glass_group  = var.break_glass_admins_group != null ? trimspace(var.break_glass_admins_group) : ""

  bi_group_member          = local.trimmed_bi_group != "" ? (startswith(local.trimmed_bi_group, "group:") ? local.trimmed_bi_group : "group:${local.trimmed_bi_group}") : ""
  de_group_member          = local.trimmed_de_group != "" ? (startswith(local.trimmed_de_group, "group:") ? local.trimmed_de_group : "group:${local.trimmed_de_group}") : ""
  stewards_group_member    = local.trimmed_stewards_group != "" ? (startswith(local.trimmed_stewards_group, "group:") ? local.trimmed_stewards_group : "group:${local.trimmed_stewards_group}") : ""
  break_glass_group_member = local.trimmed_break_glass_group != "" ? (startswith(local.trimmed_break_glass_group, "group:") ? local.trimmed_break_glass_group : "group:${local.trimmed_break_glass_group}") : ""
  batch_loader_member      = local.trimmed_batch_loader_sa != "" ? (startswith(local.trimmed_batch_loader_sa, "serviceAccount:") ? local.trimmed_batch_loader_sa : "serviceAccount:${local.trimmed_batch_loader_sa}") : ""
  dataform_sa_member       = local.trimmed_dataform_sa != "" ? (startswith(local.trimmed_dataform_sa, "serviceAccount:") ? local.trimmed_dataform_sa : "serviceAccount:${local.trimmed_dataform_sa}") : ""

  all_bi_analysts    = distinct(compact(concat(var.bi_analysts, [local.bi_group_member])))
  all_masked_readers = distinct(compact(concat(var.masked_readers, local.all_bi_analysts)))

  vpc_sc_ingress_members = distinct(compact([
    local.dataform_sa_member,
    local.batch_loader_member,
    local.bi_group_member,
  ]))

  data_gov_project_id  = "${local.project_prefix}-data-gov"
  data_core_project_id = "${local.project_prefix}-data-core"
  data_etl_project_id  = "${local.project_prefix}-data-etl"
  data_bi_project_id   = "${local.project_prefix}-data-bi"

  core_datasets = {
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
    quarantine = {
      dataset_id                      = "${local.dataset_prefix}_quarantine"
      default_table_expiration_ms     = var.ephemeral_table_expiration_ms
      default_partition_expiration_ms = var.ephemeral_partition_expiration_ms
    }
  }

  finops_env_tag_key = var.environment == "prod" ? "environment.prod" : "environment.nonprod"
  project_tag_bindings = merge(
    contains(keys(var.finops_tag_value_ids), "cost_center.data") ? { cost_center = var.finops_tag_value_ids["cost_center.data"] } : {},
    contains(keys(var.finops_tag_value_ids), local.finops_env_tag_key) ? { environment = var.finops_tag_value_ids[local.finops_env_tag_key] } : {},
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

  vpc_sc_project_numbers = merge(
    {
      gov  = module.data_gov.project_number
      core = module.data_core.project_number
      etl  = module.data_etl.project_number
      bi   = module.data_bi.project_number
    },
    { for k, m in module.data_domain : "domain_${k}" => m.project_number },
  )

  all_data_project_ids = merge(
    {
      gov  = module.data_gov.project_id
      core = module.data_core.project_id
      etl  = module.data_etl.project_id
      bi   = module.data_bi.project_id
    },
    { for k, m in module.data_domain : "domain_${k}" => m.project_id },
  )

  env_labels = merge(var.labels, { environment = var.environment })
}

resource "terraform_data" "validate_primary_domain" {
  lifecycle {
    precondition {
      condition     = contains(var.domain_marts, var.primary_domain)
      error_message = "primary_domain must be included in domain_marts."
    }

    precondition {
      condition     = !local.create_subfolders || local.parent_folder != ""
      error_message = "Provide environment_storage_folder_ids/environment_compute_folder_ids, storage_folder_id/compute_folder_id, or data_folder_id."
    }
  }
}

resource "google_folder" "storage" {
  count = local.create_subfolders ? 1 : 0

  display_name        = "storage"
  parent              = local.parent_folder
  deletion_protection = var.deletion_protection

  depends_on = [terraform_data.validate_primary_domain]
}

resource "google_folder" "compute" {
  count = local.create_subfolders ? 1 : 0

  display_name        = "compute"
  parent              = local.parent_folder
  deletion_protection = var.deletion_protection

  depends_on = [terraform_data.validate_primary_domain]
}

module "data_gov" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.data_gov_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Data Governance", 0, 30), " ")
  folder_id       = local.effective_storage_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = [
    "datacatalog.googleapis.com",
    "bigquerydatapolicy.googleapis.com",
    "dataplex.googleapis.com",
    "iam.googleapis.com",
  ]
}

module "data_core" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.data_core_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Data Core Storage", 0, 30), " ")
  folder_id       = local.effective_storage_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = [
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "dataplex.googleapis.com",
    "iam.googleapis.com",
  ]
}

module "data_domain" {
  for_each = var.domain_marts
  source   = "../../../modules/foundation/project-factory"

  project_id      = "${local.project_prefix}-data-${each.key}"
  project_name    = trimsuffix(substr("${local.project_prefix} Data Mart ${each.key}", 0, 30), " ")
  folder_id       = local.effective_storage_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = [
    "bigquery.googleapis.com",
    "dataplex.googleapis.com",
    "iam.googleapis.com",
  ]
}

module "data_etl" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.data_etl_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Data ETL Compute", 0, 30), " ")
  folder_id       = local.effective_compute_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = [
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "bigqueryreservation.googleapis.com",
    "dataform.googleapis.com",
    "secretmanager.googleapis.com",
    "dataplex.googleapis.com",
    "iam.googleapis.com",
    "run.googleapis.com",
  ]
}

module "data_bi" {
  source = "../../../modules/foundation/project-factory"

  project_id      = local.data_bi_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Data BI Compute", 0, 30), " ")
  folder_id       = local.effective_compute_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = [
    "bigquery.googleapis.com",
    "iam.googleapis.com",
  ]
}

resource "time_sleep" "gov_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.data_gov]
}

resource "time_sleep" "storage_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    module.data_core,
    module.data_domain,
  ]
}

resource "time_sleep" "compute_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [
    module.data_etl,
    module.data_bi,
  ]
}

resource "google_compute_shared_vpc_service_project" "etl" {
  count = local.effective_shared_vpc_host != "" ? 1 : 0

  host_project    = local.effective_shared_vpc_host
  service_project = module.data_etl.project_id

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_compute_shared_vpc_service_project" "bi" {
  count = local.effective_shared_vpc_host != "" ? 1 : 0

  host_project    = local.effective_shared_vpc_host
  service_project = module.data_bi.project_id

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_service_identity" "artifactregistry_etl" {
  provider = google-beta
  project  = module.data_etl.project_id
  service  = "artifactregistry.googleapis.com"

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_service_identity" "cloudrun_etl" {
  provider = google-beta
  project  = module.data_etl.project_id
  service  = "run.googleapis.com"

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_compute_subnetwork_iam_member" "cloudrun_etl_network_user" {
  count = local.effective_shared_vpc_host != "" && trimspace(var.subnet_id != null ? var.subnet_id : "") != "" ? 1 : 0

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = element(split("/", trimspace(var.subnet_id)), length(split("/", trimspace(var.subnet_id))) - 1)
  role       = "roles/compute.networkUser"
  member     = google_project_service_identity.cloudrun_etl.member

  depends_on = [
    google_compute_shared_vpc_service_project.etl,
    google_project_service_identity.cloudrun_etl,
  ]
}

data "google_storage_project_service_account" "core" {
  count = local.use_cmek ? 1 : 0

  project    = module.data_core.project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "core" {
  count = local.use_cmek ? 1 : 0

  project    = module.data_core.project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "domain" {
  for_each = local.use_cmek ? var.domain_marts : toset([])

  project    = module.data_domain[each.key].project_id
  depends_on = [time_sleep.storage_api_propagation]
}

data "google_bigquery_default_service_account" "etl" {
  count = local.use_cmek ? 1 : 0

  project    = module.data_etl.project_id
  depends_on = [time_sleep.compute_api_propagation]
}

data "google_bigquery_default_service_account" "bi" {
  count = local.use_cmek ? 1 : 0

  project    = module.data_bi.project_id
  depends_on = [time_sleep.compute_api_propagation]
}

resource "time_sleep" "service_agent_propagation" {
  count = local.use_cmek ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [
    data.google_storage_project_service_account.core,
    data.google_bigquery_default_service_account.core,
    data.google_bigquery_default_service_account.domain,
    data.google_bigquery_default_service_account.etl,
    data.google_bigquery_default_service_account.bi,
    google_project_service_identity.artifactregistry_etl,
  ]
}

resource "google_kms_crypto_key_iam_member" "storage_core_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.core[0].email_address}"

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_core_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.core[0].member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_domain_cmek" {
  for_each = local.use_cmek ? var.domain_marts : toset([])

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.domain[each.key].member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_etl_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.etl[0].member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_bi_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.bi[0].member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "ar_etl_cmek" {
  count = local.use_cmek ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.artifactregistry_etl.member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_core_dr_cmek" {
  count = local.create_dr_datasets && local.effective_dr_kms_key_id != "" ? 1 : 0

  crypto_key_id = local.effective_dr_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.core[0].member

  depends_on = [time_sleep.service_agent_propagation]
}

resource "google_kms_crypto_key_iam_member" "bq_domain_dr_cmek" {
  for_each = local.create_dr_datasets && local.effective_dr_kms_key_id != "" ? var.domain_marts : toset([])

  crypto_key_id = local.effective_dr_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.domain[each.key].member

  depends_on = [time_sleep.service_agent_propagation]
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
    google_kms_crypto_key_iam_member.ar_etl_cmek,
    google_kms_crypto_key_iam_member.bq_core_dr_cmek,
    google_kms_crypto_key_iam_member.bq_domain_dr_cmek,
  ]
}

resource "google_project_iam_custom_role" "dataform_runner_core" {
  project     = module.data_core.project_id
  role_id     = "dataform_pipeline_runner"
  title       = "Dataform Pipeline Runner"
  description = "Least-privilege table and routine role without dataset update or delete."
  permissions = local.dataform_role_permissions

  depends_on = [time_sleep.storage_api_propagation]
}

resource "google_project_iam_custom_role" "dataform_runner_domain" {
  for_each = var.domain_marts

  project     = module.data_domain[each.key].project_id
  role_id     = "dataform_pipeline_runner"
  title       = "Dataform Pipeline Runner"
  description = "Least-privilege table and routine role without dataset update or delete."
  permissions = local.dataform_role_permissions

  depends_on = [time_sleep.storage_api_propagation]
}

resource "google_project_iam_custom_role" "dataform_runner_bi" {
  project     = module.data_bi.project_id
  role_id     = "dataform_pipeline_runner"
  title       = "Dataform Pipeline Runner"
  description = "Least-privilege table and routine role without dataset update or delete."
  permissions = local.dataform_role_permissions

  depends_on = [time_sleep.compute_api_propagation]
}

module "governance_catalog" {
  source = "../../../modules/data/governance-catalog"

  project_id           = module.data_gov.project_id
  region               = var.region
  prefix               = var.prefix
  environment          = var.environment
  masking_expression   = var.masking_expression
  masked_readers       = local.all_masked_readers
  fine_grained_readers = var.fine_grained_readers
  enable_glossary      = true
  enable_apis          = false
  labels               = local.env_labels

  depends_on = [time_sleep.gov_api_propagation]
}

resource "google_storage_bucket" "landing" {
  project                     = module.data_core.project_id
  name                        = "${module.data_core.project_id}-landing"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.delete_contents_on_destroy
  labels                      = local.env_labels

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

resource "google_artifact_registry_repository" "ingestion" {
  project       = module.data_etl.project_id
  location      = var.region
  repository_id = "${var.prefix}-ingestion"
  description   = "Container registry for Cloud Run ingestion jobs."
  format        = "DOCKER"
  kms_key_name  = local.use_cmek ? local.effective_kms_key_id : null
  labels        = local.env_labels

  docker_config {
    immutable_tags = var.environment == "prod" && var.immutable_image_tags
  }

  depends_on = [
    time_sleep.compute_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

resource "google_artifact_registry_repository_iam_member" "cloudrun_reader" {
  project    = module.data_etl.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ingestion.name
  role       = "roles/artifactregistry.reader"
  member     = google_project_service_identity.cloudrun_etl.member
}

resource "google_artifact_registry_repository_iam_member" "batch_loader_reader" {
  count = local.batch_loader_member != "" ? 1 : 0

  project    = module.data_etl.project_id
  location   = var.region
  repository = google_artifact_registry_repository.ingestion.name
  role       = "roles/artifactregistry.reader"
  member     = local.batch_loader_member
}

module "core_datasets" {
  for_each = local.core_datasets
  source   = "../../../modules/data/bigquery-dataset"

  project_id                      = module.data_core.project_id
  dataset_id                      = each.value.dataset_id
  region                          = var.region
  description                     = "Enterprise core storage dataset (${each.key})."
  default_table_expiration_ms     = each.value.default_table_expiration_ms
  default_partition_expiration_ms = each.value.default_partition_expiration_ms
  delete_contents_on_destroy      = var.delete_contents_on_destroy
  kms_key_name                    = local.use_cmek ? local.effective_kms_key_id : null
  readers                         = local.de_group_member != "" ? [local.de_group_member] : []
  labels                          = local.env_labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "domain_gold_mart" {
  for_each = var.domain_marts
  source   = "../../../modules/data/bigquery-dataset"

  project_id                 = module.data_domain[each.key].project_id
  dataset_id                 = "${local.dataset_prefix}_gold_mart"
  region                     = var.region
  description                = "Enterprise Gold mart dataset for domain ${each.key}."
  delete_contents_on_destroy = var.delete_contents_on_destroy
  kms_key_name               = local.use_cmek ? local.effective_kms_key_id : null
  readers                    = distinct(compact(concat(local.all_bi_analysts, [local.de_group_member])))
  labels                     = local.env_labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "core_dr_datasets" {
  for_each = local.create_dr_datasets ? local.core_datasets : {}
  source   = "../../../modules/data/bigquery-dataset"

  project_id                      = module.data_core.project_id
  dataset_id                      = "${each.value.dataset_id}_dr"
  region                          = local.trimmed_dr_region
  description                     = "Enterprise DR core dataset (${each.key})."
  default_table_expiration_ms     = each.value.default_table_expiration_ms
  default_partition_expiration_ms = each.value.default_partition_expiration_ms
  delete_contents_on_destroy      = var.delete_contents_on_destroy
  kms_key_name                    = local.effective_dr_kms_key_id != "" ? local.effective_dr_kms_key_id : null
  readers                         = local.de_group_member != "" ? [local.de_group_member] : []
  labels                          = local.env_labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "domain_gold_mart_dr" {
  for_each = local.create_dr_datasets ? var.domain_marts : toset([])
  source   = "../../../modules/data/bigquery-dataset"

  project_id                 = module.data_domain[each.key].project_id
  dataset_id                 = "${local.dataset_prefix}_gold_mart_dr"
  region                     = local.trimmed_dr_region
  description                = "Enterprise DR Gold mart dataset for domain ${each.key}."
  delete_contents_on_destroy = var.delete_contents_on_destroy
  kms_key_name               = local.effective_dr_kms_key_id != "" ? local.effective_dr_kms_key_id : null
  readers                    = distinct(compact(concat(local.all_bi_analysts, [local.de_group_member])))
  labels                     = local.env_labels

  depends_on = [
    time_sleep.storage_api_propagation,
    time_sleep.cmek_iam_propagation,
  ]
}

module "reservations" {
  count  = var.enable_reservations ? 1 : 0
  source = "../../../modules/data/bigquery-reservations"

  project_id    = module.data_etl.project_id
  region        = var.region
  prefix        = var.prefix
  bi_project_id = module.data_bi.project_id
  labels        = local.env_labels

  reservations = {
    etl = {
      edition           = "ENTERPRISE"
      slot_capacity     = var.etl_baseline_slots != null ? var.etl_baseline_slots : var.baseline_slots
      ignore_idle_slots = false
      max_slots         = var.etl_max_slots != null ? var.etl_max_slots : var.max_slots
    }
    bi = {
      edition           = "ENTERPRISE"
      slot_capacity     = var.bi_baseline_slots != null ? var.bi_baseline_slots : var.baseline_slots
      ignore_idle_slots = false
      max_slots         = var.bi_max_slots != null ? var.bi_max_slots : var.max_slots
    }
    adhoc = {
      edition           = "ENTERPRISE"
      slot_capacity     = var.adhoc_baseline_slots != null ? var.adhoc_baseline_slots : var.baseline_slots
      ignore_idle_slots = false
      max_slots         = var.adhoc_max_slots != null ? var.adhoc_max_slots : var.max_slots
    }
  }

  assignments = merge(
    { (local.data_etl_project_id) = "etl" },
    var.reservation_assignments,
  )

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_iam_member" "bi_analysts_job_user" {
  for_each = toset(local.all_bi_analysts)

  project = module.data_bi.project_id
  role    = "roles/bigquery.jobUser"
  member  = each.value

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_iam_member" "data_engineers_job_user" {
  count = local.de_group_member != "" ? 1 : 0

  project = module.data_etl.project_id
  role    = "roles/bigquery.jobUser"
  member  = local.de_group_member

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_project_iam_member" "data_engineers_dataform" {
  count = local.de_group_member != "" ? 1 : 0

  project = module.data_etl.project_id
  role    = "roles/dataform.editor"
  member  = local.de_group_member

  depends_on = [time_sleep.compute_api_propagation]
}

resource "google_storage_bucket_iam_member" "data_engineers_landing_viewer" {
  count = local.de_group_member != "" ? 1 : 0

  bucket = google_storage_bucket.landing.name
  role   = "roles/storage.objectViewer"
  member = local.de_group_member
}

resource "google_project_iam_member" "governance_stewards_datacatalog" {
  count = local.stewards_group_member != "" ? 1 : 0

  project = module.data_gov.project_id
  role    = "roles/datacatalog.admin"
  member  = local.stewards_group_member

  depends_on = [time_sleep.gov_api_propagation]
}

resource "google_project_iam_member" "governance_stewards_dataplex" {
  count = local.stewards_group_member != "" ? 1 : 0

  project = module.data_gov.project_id
  role    = "roles/dataplex.admin"
  member  = local.stewards_group_member

  depends_on = [time_sleep.gov_api_propagation]
}

resource "google_project_iam_member" "governance_stewards_datapolicy" {
  count = local.stewards_group_member != "" ? 1 : 0

  project = module.data_gov.project_id
  role    = "roles/bigquerydatapolicy.admin"
  member  = local.stewards_group_member

  depends_on = [time_sleep.gov_api_propagation]
}

resource "google_project_iam_member" "break_glass_bigquery" {
  for_each = local.break_glass_group_member != "" ? local.all_data_project_ids : {}

  project = each.value
  role    = "roles/bigquery.admin"
  member  = local.break_glass_group_member

  depends_on = [
    time_sleep.gov_api_propagation,
    time_sleep.storage_api_propagation,
    time_sleep.compute_api_propagation,
  ]
}

resource "google_project_iam_member" "break_glass_iam" {
  for_each = local.break_glass_group_member != "" ? local.all_data_project_ids : {}

  project = each.value
  role    = "roles/resourcemanager.projectIamAdmin"
  member  = local.break_glass_group_member

  depends_on = [
    time_sleep.gov_api_propagation,
    time_sleep.storage_api_propagation,
    time_sleep.compute_api_propagation,
  ]
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "data_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && !var.enforce_vpc_sc ? local.vpc_sc_project_numbers : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_resource" "data_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && var.enforce_vpc_sc ? local.vpc_sc_project_numbers : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "runtime_bi" {
  count = local.effective_vpc_sc_perimeter != "" && !var.enforce_vpc_sc && length(local.vpc_sc_ingress_members) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-platform-ingress"

  ingress_from {
    identities = local.vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = [for num in values(local.vpc_sc_project_numbers) : "projects/${num}"]
    operations {
      service_name = "*"
    }
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "runtime_bi" {
  count = local.effective_vpc_sc_perimeter != "" && var.enforce_vpc_sc && length(local.vpc_sc_ingress_members) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-platform-ingress"

  ingress_from {
    identities = local.vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = [for num in values(local.vpc_sc_project_numbers) : "projects/${num}"]
    operations {
      service_name = "*"
    }
  }
}
