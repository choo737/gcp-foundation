resource "google_service_account" "etl" {
  count = var.service_account_email == "" ? 1 : 0

  project      = var.project_id
  account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-etl"), 0, 30), "-")
  display_name = "${var.prefix} Dataform ETL"
  description  = "Dedicated service account for Dataform workflow runs."
}

locals {
  effective_sa_email          = var.service_account_email != "" ? var.service_account_email : google_service_account.etl[0].email
  effective_database          = var.default_database != "" ? var.default_database : var.project_id
  effective_kms_key_name      = var.kms_key_name != null ? trimspace(var.kms_key_name) : ""
  enable_git_remote           = var.git_remote_url != "" && var.git_token_secret_version != ""
  trimmed_release_config_name = var.release_config_name != null ? trimspace(var.release_config_name) : ""
  effective_release_name      = local.trimmed_release_config_name != "" ? local.trimmed_release_config_name : "${var.environment}-main"
  trimmed_workflow_name       = var.workflow_config_name != null ? trimspace(var.workflow_config_name) : ""
  effective_workflow_name     = local.trimmed_workflow_name != "" ? local.trimmed_workflow_name : "${var.environment}-daily"
  trimmed_release_cron        = var.release_cron_schedule != null ? trimspace(var.release_cron_schedule) : ""
  effective_release_cron      = local.trimmed_release_cron != "" ? local.trimmed_release_cron : (var.enable_scheduled_workflow ? "45 1 * * *" : null)
  effective_pii_masked_tag    = var.pii_masked_policy_tag != "" ? var.pii_masked_policy_tag : var.pii_policy_tag

  compilation_vars = merge(
    {
      bronze_project            = var.bronze_project != "" ? var.bronze_project : var.project_id
      bronze_dataset            = var.bronze_dataset
      silver_project            = var.silver_project != "" ? var.silver_project : var.project_id
      silver_dataset            = var.silver_dataset
      gold_project              = var.gold_project != "" ? var.gold_project : var.project_id
      gold_dataset              = var.gold_dataset
      pii_policy_tag            = local.effective_pii_masked_tag
      pii_masked_policy_tag     = local.effective_pii_masked_tag
      pii_restricted_policy_tag = var.pii_restricted_policy_tag
    },
    var.extra_compilation_vars,
  )
}

resource "google_dataform_repository" "this" {
  project         = var.project_id
  region          = var.region
  name            = var.repository_name
  display_name    = coalesce(var.display_name, var.repository_name)
  service_account = local.effective_sa_email
  kms_key_name    = local.effective_kms_key_name != "" ? local.effective_kms_key_name : null
  deletion_policy = var.deletion_policy
  labels          = var.labels

  dynamic "git_remote_settings" {
    for_each = local.enable_git_remote ? [1] : []
    content {
      url                                 = var.git_remote_url
      default_branch                      = var.git_default_branch
      authentication_token_secret_version = var.git_token_secret_version
    }
  }
}

resource "google_dataform_repository_release_config" "prod" {
  count = local.enable_git_remote ? 1 : 0

  project       = var.project_id
  region        = var.region
  repository    = google_dataform_repository.this.name
  name          = local.effective_release_name
  git_commitish = var.git_release_commitish != "" ? var.git_release_commitish : var.git_default_branch
  time_zone     = "Asia/Kuala_Lumpur"
  cron_schedule = local.effective_release_cron

  code_compilation_config {
    default_database = local.effective_database
    default_schema   = var.silver_dataset
    default_location = var.region
    assertion_schema = var.assertion_schema
    vars             = local.compilation_vars
  }
}

resource "google_dataform_repository_workflow_config" "scheduled" {
  count = var.enable_scheduled_workflow && local.enable_git_remote ? 1 : 0

  project        = var.project_id
  region         = var.region
  repository     = google_dataform_repository.this.name
  name           = local.effective_workflow_name
  release_config = google_dataform_repository_release_config.prod[0].id
  cron_schedule  = var.workflow_cron_schedule
  time_zone      = "Asia/Kuala_Lumpur"

  invocation_config {
    service_account = local.effective_sa_email
  }
}
