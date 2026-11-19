provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

locals {
  project_prefix   = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  dataset_prefix   = replace(var.prefix, "-", "_")
  is_small_tier    = var.team_size_tier == "S"
  create_projects  = var.enable_data_science && !local.is_small_tier
  env_labels       = merge(var.labels, { environment = var.environment })
  trimmed_etl_proj = var.etl_compute_project_id != null ? trimspace(var.etl_compute_project_id) : ""
  trimmed_gov_proj = var.governance_project_id != null ? trimspace(var.governance_project_id) : ""
  trimmed_core     = var.core_storage_project_id != null ? trimspace(var.core_storage_project_id) : ""
  trimmed_silver   = var.silver_dataset_id != null ? trimspace(var.silver_dataset_id) : ""
  trimmed_gold     = var.primary_gold_project_id != null ? trimspace(var.primary_gold_project_id) : ""
  trimmed_gold_ds  = var.primary_gold_dataset_id != null ? trimspace(var.primary_gold_dataset_id) : ""
  trimmed_billing  = var.billing_account != null ? trimspace(var.billing_account) : ""

  env_compute_folder_id       = lookup(var.environment_compute_folder_ids, var.environment, "")
  trimmed_compute_folder_id   = var.compute_folder_id != null ? trimspace(var.compute_folder_id) : ""
  effective_compute_folder_id = local.env_compute_folder_id != "" ? local.env_compute_folder_id : local.trimmed_compute_folder_id

  effective_kms_key_id       = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek                   = local.effective_kms_key_id != ""
  effective_shared_vpc_host  = var.shared_vpc_host_project_id != null ? trimspace(var.shared_vpc_host_project_id) : ""
  effective_vpc_id           = var.vpc_id != null ? trimspace(var.vpc_id) : ""
  effective_subnet_id        = var.subnet_id != null ? trimspace(var.subnet_id) : ""
  effective_vpc_sc_perimeter = var.vpc_sc_perimeter_name != null ? trimspace(var.vpc_sc_perimeter_name) : ""

  trimmed_data_policy_short = var.pii_data_policy_short_id != null ? trimspace(var.pii_data_policy_short_id) : ""
  effective_data_policy_short_id = (
    local.trimmed_data_policy_short != ""
    ? local.trimmed_data_policy_short
    : "${local.dataset_prefix}_pii_mask"
  )

  trimmed_ds_group = var.ds_analysts_group != null ? trimspace(var.ds_analysts_group) : ""
  ds_group_member = local.trimmed_ds_group != "" ? (
    startswith(local.trimmed_ds_group, "group:") ||
    startswith(local.trimmed_ds_group, "user:") ||
    startswith(local.trimmed_ds_group, "serviceAccount:")
    ? local.trimmed_ds_group
    : "group:${local.trimmed_ds_group}"
  ) : ""

  ds_exp_project_id_candidate = "${local.project_prefix}-ds-exp"
  ml_ops_project_id_candidate = "${local.project_prefix}-ml-ops"

  effective_ds_exp_project_id = var.enable_data_science ? (
    local.is_small_tier ? local.trimmed_etl_proj : module.ds_exp_project[0].project_id
  ) : ""

  effective_ml_ops_project_id = var.enable_data_science ? (
    local.is_small_tier ? local.trimmed_etl_proj : module.ml_ops_project[0].project_id
  ) : ""

  ds_exp_project_number = var.enable_data_science ? (
    local.is_small_tier ? try(data.google_project.tier_s_etl[0].number, "") : try(module.ds_exp_project[0].project_number, "")
  ) : ""

  ml_ops_project_number = var.enable_data_science ? (
    local.is_small_tier ? try(data.google_project.tier_s_etl[0].number, "") : try(module.ml_ops_project[0].project_number, "")
  ) : ""

  finops_env_tag_key = var.environment == "prod" ? "environment.prod" : "environment.nonprod"
  project_tag_bindings = merge(
    contains(keys(var.finops_tag_value_ids), "cost_center.data") ? { cost_center = var.finops_tag_value_ids["cost_center.data"] } : {},
    contains(keys(var.finops_tag_value_ids), local.finops_env_tag_key) ? { environment = var.finops_tag_value_ids[local.finops_env_tag_key] } : {},
  )

  ds_required_apis = toset([
    "aiplatform.googleapis.com",
    "notebooks.googleapis.com",
    "datalineage.googleapis.com",
    "artifactregistry.googleapis.com",
    "bigquery.googleapis.com",
    "storage.googleapis.com",
    "dataplex.googleapis.com",
    "run.googleapis.com",
  ])

  created_vpc_sc_projects = local.create_projects ? {
    ds_exp = module.ds_exp_project[0].project_number
    ml_ops = module.ml_ops_project[0].project_number
  } : {}

  workbench_sa_member = var.enable_data_science ? google_service_account.workbench_runtime[0].member : ""
  dataset_viewer_members = var.enable_data_science ? merge(
    { workbench_sa = local.workbench_sa_member },
    local.ds_group_member != "" ? { ds_analysts = local.ds_group_member } : {},
  ) : {}

  vpc_sc_ingress_members = var.enable_data_science ? distinct(compact([
    local.workbench_sa_member,
    local.ds_group_member,
    try(google_project_service_identity.aiplatform_ml_ops[0].member, ""),
    try(google_project_service_identity.dataplex_ml_ops[0].member, ""),
  ])) : []

  vpc_sc_ingress_target_projects = var.enable_data_science ? distinct(compact([
    local.ds_exp_project_number != "" ? "projects/${local.ds_exp_project_number}" : "",
    local.ml_ops_project_number != "" ? "projects/${local.ml_ops_project_number}" : "",
    length(data.google_project.core) > 0 ? "projects/${data.google_project.core[0].number}" : "",
    length(data.google_project.gold) > 0 ? "projects/${data.google_project.gold[0].number}" : "",
  ])) : []
}

resource "terraform_data" "validate_stage_inputs" {
  count = var.enable_data_science ? 1 : 0

  lifecycle {
    precondition {
      condition     = !(var.enable_colab_enterprise && var.compliance_profile == "regulated_fsi_rmit")
      error_message = "enable_colab_enterprise = true is blocked when compliance_profile is regulated_fsi_rmit."
    }

    precondition {
      condition     = !local.is_small_tier || local.trimmed_etl_proj != ""
      error_message = "etl_compute_project_id is required when team_size_tier is S."
    }

    precondition {
      condition     = local.is_small_tier || (local.effective_compute_folder_id != "" && local.trimmed_billing != "")
      error_message = "compute_folder_id (or environment_compute_folder_ids) and billing_account are required when team_size_tier is M or L."
    }

    precondition {
      condition     = local.is_small_tier || (length(local.ds_exp_project_id_candidate) <= 30 && length(local.ml_ops_project_id_candidate) <= 30)
      error_message = "Combined prefix and project_suffix must keep -ds-exp and -ml-ops project IDs within 30 characters."
    }
  }
}

module "ds_exp_project" {
  count  = local.create_projects ? 1 : 0
  source = "../../../modules/foundation/project-factory"

  project_id      = local.ds_exp_project_id_candidate
  project_name    = trimsuffix(substr("${local.project_prefix} DS Experiment", 0, 30), " ")
  folder_id       = local.effective_compute_folder_id
  billing_account = local.trimmed_billing
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = concat(
    tolist(local.ds_required_apis),
    ["compute.googleapis.com", "iam.googleapis.com"],
  )

  depends_on = [terraform_data.validate_stage_inputs]
}

module "ml_ops_project" {
  count  = local.create_projects ? 1 : 0
  source = "../../../modules/foundation/project-factory"

  project_id      = local.ml_ops_project_id_candidate
  project_name    = trimsuffix(substr("${local.project_prefix} ML Ops", 0, 30), " ")
  folder_id       = local.effective_compute_folder_id
  billing_account = local.trimmed_billing
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = local.env_labels

  activate_apis = concat(
    tolist(local.ds_required_apis),
    ["compute.googleapis.com", "iam.googleapis.com"],
  )

  depends_on = [terraform_data.validate_stage_inputs]
}

resource "google_project_service" "tier_s_apis" {
  for_each = var.enable_data_science && local.is_small_tier ? local.ds_required_apis : toset([])

  project                    = local.trimmed_etl_proj
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false

  depends_on = [terraform_data.validate_stage_inputs]
}

data "google_project" "tier_s_etl" {
  count = var.enable_data_science && local.is_small_tier ? 1 : 0

  project_id = local.trimmed_etl_proj
  depends_on = [terraform_data.validate_stage_inputs]
}

data "google_project" "core" {
  count = var.enable_data_science && local.trimmed_core != "" ? 1 : 0

  project_id = local.trimmed_core
}

data "google_project" "gold" {
  count = var.enable_data_science && local.trimmed_gold != "" ? 1 : 0

  project_id = local.trimmed_gold
}

resource "time_sleep" "ds_api_propagation" {
  count = var.enable_data_science ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [
    module.ds_exp_project,
    module.ml_ops_project,
    google_project_service.tier_s_apis,
  ]
}

resource "google_compute_shared_vpc_service_project" "ds_exp" {
  count = local.create_projects && local.effective_shared_vpc_host != "" ? 1 : 0

  host_project    = local.effective_shared_vpc_host
  service_project = module.ds_exp_project[0].project_id

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_compute_shared_vpc_service_project" "ml_ops" {
  count = local.create_projects && local.effective_shared_vpc_host != "" ? 1 : 0

  host_project    = local.effective_shared_vpc_host
  service_project = module.ml_ops_project[0].project_id

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_service_account" "workbench_runtime" {
  count = var.enable_data_science ? 1 : 0

  project      = local.effective_ds_exp_project_id
  account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-wb-runtime"), 0, 30), "-")
  display_name = "${var.prefix} Workbench Runtime"
  description  = "Dedicated least-privilege runtime service account for Vertex AI Workbench instances."

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_compute_subnetwork_iam_member" "workbench_network_user" {
  count = var.enable_data_science && local.effective_shared_vpc_host != "" && local.effective_subnet_id != "" ? 1 : 0

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = element(split("/", local.effective_subnet_id), length(split("/", local.effective_subnet_id)) - 1)
  role       = "roles/compute.networkUser"
  member     = google_service_account.workbench_runtime[0].member

  depends_on = [google_compute_shared_vpc_service_project.ds_exp]
}

resource "google_project_service_identity" "aiplatform_ml_ops" {
  count    = var.enable_data_science ? 1 : 0
  provider = google-beta

  project = local.effective_ml_ops_project_id
  service = "aiplatform.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_service_identity" "aiplatform_ds_exp" {
  count    = local.create_projects ? 1 : 0
  provider = google-beta

  project = module.ds_exp_project[0].project_id
  service = "aiplatform.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_service_identity" "notebooks_ds_exp" {
  count    = var.enable_data_science ? 1 : 0
  provider = google-beta

  project = local.effective_ds_exp_project_id
  service = "notebooks.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_service_identity" "dataplex_ml_ops" {
  count    = var.enable_data_science ? 1 : 0
  provider = google-beta

  project = local.effective_ml_ops_project_id
  service = "dataplex.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_service_identity" "artifactregistry_ml_ops" {
  count    = var.enable_data_science ? 1 : 0
  provider = google-beta

  project = local.effective_ml_ops_project_id
  service = "artifactregistry.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_service_identity" "cloudrun_ml_ops" {
  count    = var.enable_data_science ? 1 : 0
  provider = google-beta

  project = local.effective_ml_ops_project_id
  service = "run.googleapis.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_compute_subnetwork_iam_member" "cloudrun_ml_ops_network_user" {
  count = var.enable_data_science && local.effective_shared_vpc_host != "" && local.effective_subnet_id != "" ? 1 : 0

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = element(split("/", local.effective_subnet_id), length(split("/", local.effective_subnet_id)) - 1)
  role       = "roles/compute.networkUser"
  member     = google_project_service_identity.cloudrun_ml_ops[0].member

  depends_on = [
    google_compute_shared_vpc_service_project.ml_ops,
    google_project_service_identity.cloudrun_ml_ops,
  ]
}

data "google_storage_project_service_account" "ml_ops" {
  count = var.enable_data_science && local.use_cmek ? 1 : 0

  project    = local.effective_ml_ops_project_id
  depends_on = [time_sleep.ds_api_propagation]
}

data "google_bigquery_default_service_account" "ml_ops" {
  count = var.enable_data_science && local.use_cmek ? 1 : 0

  project    = local.effective_ml_ops_project_id
  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_kms_crypto_key_iam_member" "aiplatform_ml_ops_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.aiplatform_ml_ops[0].member
}

resource "google_kms_crypto_key_iam_member" "aiplatform_ds_exp_cmek" {
  count = local.create_projects && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.aiplatform_ds_exp[0].member
}

resource "google_kms_crypto_key_iam_member" "notebooks_ds_exp_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.notebooks_ds_exp[0].member
}

resource "google_kms_crypto_key_iam_member" "compute_system_ds_exp_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${local.ds_exp_project_number}@compute-system.iam.gserviceaccount.com"

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_kms_crypto_key_iam_member" "storage_ml_ops_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_storage_project_service_account.ml_ops[0].email_address}"
}

resource "google_kms_crypto_key_iam_member" "bq_ml_ops_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = data.google_bigquery_default_service_account.ml_ops[0].member
}

resource "google_kms_crypto_key_iam_member" "ar_ml_ops_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.artifactregistry_ml_ops[0].member
}

resource "google_kms_crypto_key_iam_member" "dataplex_ml_ops_cmek" {
  count = var.enable_data_science && local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.dataplex_ml_ops[0].member
}

# Separation-of-Duties IAM: experimentation access in ds-exp only (never aiplatform.user in ml-ops or Tier S prod).
resource "google_project_iam_member" "ds_analysts_ds_exp_bq_job_user" {
  count = var.enable_data_science && local.ds_group_member != "" && (var.team_size_tier != "S" || var.environment != "prod") ? 1 : 0

  project = local.effective_ds_exp_project_id
  role    = "roles/bigquery.jobUser"
  member  = local.ds_group_member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "ds_analysts_ds_exp_notebooks_viewer" {
  count = var.enable_data_science && local.ds_group_member != "" && (var.team_size_tier != "S" || var.environment != "prod") ? 1 : 0

  project = local.effective_ds_exp_project_id
  role    = "roles/notebooks.viewer"
  member  = local.ds_group_member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "ds_analysts_ds_exp_aiplatform_user" {
  count = var.enable_data_science && local.ds_group_member != "" && (var.team_size_tier != "S" || var.environment != "prod") ? 1 : 0

  project = local.effective_ds_exp_project_id
  role    = "roles/aiplatform.user"
  member  = local.ds_group_member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "ds_analysts_ml_ops_aiplatform_viewer" {
  count = var.enable_data_science && local.ds_group_member != "" ? 1 : 0

  project = local.effective_ml_ops_project_id
  role    = "roles/aiplatform.viewer"
  member  = local.ds_group_member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "workbench_runtime_bq_job_user" {
  count = var.enable_data_science ? 1 : 0

  project = local.effective_ds_exp_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_service_account.workbench_runtime[0].member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "dataplex_ml_ops_job_user" {
  count = var.enable_data_science && var.enable_xai_quality_scan ? 1 : 0

  project = local.effective_ml_ops_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_project_service_identity.dataplex_ml_ops[0].member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_project_iam_member" "dataplex_ml_ops_service_agent" {
  count = var.enable_data_science && var.enable_xai_quality_scan ? 1 : 0

  project = local.effective_ml_ops_project_id
  role    = "roles/dataplex.serviceAgent"
  member  = google_project_service_identity.dataplex_ml_ops[0].member

  depends_on = [time_sleep.ds_api_propagation]
}

resource "google_bigquery_dataset_iam_member" "silver_viewer" {
  for_each = local.trimmed_core != "" && local.trimmed_silver != "" ? local.dataset_viewer_members : {}

  project    = local.trimmed_core
  dataset_id = local.trimmed_silver
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

resource "google_bigquery_dataset_iam_member" "aiplatform_ml_ops_silver_viewer" {
  count = var.enable_data_science && local.trimmed_core != "" && local.trimmed_silver != "" ? 1 : 0

  project    = local.trimmed_core
  dataset_id = local.trimmed_silver
  role       = "roles/bigquery.dataViewer"
  member     = google_project_service_identity.aiplatform_ml_ops[0].member

  depends_on = [google_project_service_identity.aiplatform_ml_ops]
}

resource "google_project_iam_member" "aiplatform_ml_ops_bq_job_user" {
  count = var.enable_data_science ? 1 : 0

  project = local.effective_ml_ops_project_id
  role    = "roles/bigquery.jobUser"
  member  = google_project_service_identity.aiplatform_ml_ops[0].member

  depends_on = [google_project_service_identity.aiplatform_ml_ops]
}

resource "google_bigquery_dataset_iam_member" "gold_viewer" {
  for_each = local.trimmed_gold != "" && local.trimmed_gold_ds != "" ? local.dataset_viewer_members : {}

  project    = local.trimmed_gold
  dataset_id = local.trimmed_gold_ds
  role       = "roles/bigquery.dataViewer"
  member     = each.value
}

# Grant maskedReader on pii_masked Data Policy only; restricted tags stay excluded.
resource "google_bigquery_datapolicy_data_policy_iam_member" "pii_masked_reader" {
  for_each = local.trimmed_gov_proj != "" && local.effective_data_policy_short_id != "" ? local.dataset_viewer_members : {}

  project        = local.trimmed_gov_proj
  location       = var.region
  data_policy_id = local.effective_data_policy_short_id
  role           = "roles/bigquerydatapolicy.maskedReader"
  member         = each.value
}

resource "time_sleep" "ds_cmek_and_iam_propagation" {
  count = var.enable_data_science ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_kms_crypto_key_iam_member.aiplatform_ml_ops_cmek,
    google_kms_crypto_key_iam_member.aiplatform_ds_exp_cmek,
    google_kms_crypto_key_iam_member.notebooks_ds_exp_cmek,
    google_kms_crypto_key_iam_member.compute_system_ds_exp_cmek,
    google_kms_crypto_key_iam_member.storage_ml_ops_cmek,
    google_kms_crypto_key_iam_member.bq_ml_ops_cmek,
    google_kms_crypto_key_iam_member.ar_ml_ops_cmek,
    google_kms_crypto_key_iam_member.dataplex_ml_ops_cmek,
    google_compute_subnetwork_iam_member.workbench_network_user,
    google_compute_shared_vpc_service_project.ml_ops,
    google_compute_subnetwork_iam_member.cloudrun_ml_ops_network_user,
    google_bigquery_dataset_iam_member.aiplatform_ml_ops_silver_viewer,
    google_project_iam_member.aiplatform_ml_ops_bq_job_user,
    google_project_iam_member.dataplex_ml_ops_job_user,
    google_project_iam_member.dataplex_ml_ops_service_agent,
  ]
}

module "ml_governance" {
  count  = var.enable_data_science ? 1 : 0
  source = "../../../modules/data/ml-governance"

  ds_exp_project_id              = local.effective_ds_exp_project_id
  ml_ops_project_id              = local.effective_ml_ops_project_id
  region                         = var.region
  prefix                         = var.prefix
  environment                    = var.environment
  compliance_profile             = var.compliance_profile
  kms_key_id                     = local.effective_kms_key_id
  manage_kms_iam                 = var.manage_kms_iam
  vpc_id                         = local.effective_vpc_id
  subnet_id                      = local.effective_subnet_id
  enable_vertex_psc_policy       = var.enable_vertex_psc_policy
  enable_ds_workbench            = var.enable_ds_workbench
  workbench_runtime_sa_email     = google_service_account.workbench_runtime[0].email
  workbench_idle_timeout_seconds = var.workbench_idle_timeout_seconds
  workbench_instances            = var.workbench_instances
  enable_colab_enterprise        = var.enable_colab_enterprise
  colab_machine_type             = var.colab_machine_type
  xai_audit_retention_days       = var.xai_audit_retention_days
  shap_additivity_tolerance      = var.shap_additivity_tolerance
  enable_xai_quality_scan        = var.enable_xai_quality_scan
  xai_quality_schedule_cron      = var.xai_quality_schedule_cron
  delete_contents_on_destroy     = var.delete_contents_on_destroy
  labels                         = local.env_labels

  depends_on = [time_sleep.ds_cmek_and_iam_propagation]
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "ds_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && !var.enforce_vpc_sc ? local.created_vpc_sc_projects : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_resource" "ds_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && var.enforce_vpc_sc ? local.created_vpc_sc_projects : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "ds_runtime" {
  count = var.enable_data_science && local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && !var.enforce_vpc_sc && length(local.vpc_sc_ingress_members) > 0 && length(local.vpc_sc_ingress_target_projects) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-ds-xai-ingress"

  ingress_from {
    identities = local.vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.vpc_sc_ingress_target_projects
    operations {
      service_name = "*"
    }
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "ds_runtime" {
  count = var.enable_data_science && local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && var.enforce_vpc_sc && length(local.vpc_sc_ingress_members) > 0 && length(local.vpc_sc_ingress_target_projects) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-ds-xai-ingress"

  ingress_from {
    identities = local.vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.vpc_sc_ingress_target_projects
    operations {
      service_name = "*"
    }
  }
}
