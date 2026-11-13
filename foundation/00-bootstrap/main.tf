provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  bucket_prefix = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix

  required_apis = toset([
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "iam.googleapis.com",
    "storage.googleapis.com",
  ])

  ci_service_accounts = {
    tf_foundation_ci = {
      account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-tf-foundation-ci"), 0, 30), "-")
      display_name = "${var.prefix} Foundation CI"
      description  = "Service account for GitHub Actions gcp-foundation Terraform runs."
    }
    tf_ingestion_ci = {
      account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-tf-ingestion-ci"), 0, 30), "-")
      display_name = "${var.prefix} Ingestion CI"
      description  = "Service account for GitHub Actions gcp-data-ingestion Terraform runs."
    }
    dataform_ci = {
      account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-dataform-ci"), 0, 30), "-")
      display_name = "${var.prefix} Dataform CI"
      description  = "Service account for GitHub Actions Dataform compilation checks."
    }
  }

  default_ci_bindings = (
    var.enable_ci_service_accounts
    ? {
      for k, sa in google_service_account.ci :
      k => {
        service_account_id = sa.name
        repositories       = lookup(var.ci_repository_map, k, [])
      }
      if length(lookup(var.ci_repository_map, k, [])) > 0
    }
    : {}
  )

  effective_sa_bindings = merge(local.default_ci_bindings, var.service_account_bindings)
}

resource "google_project_service" "bootstrap_apis" {
  for_each = local.required_apis

  project                    = var.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "time_sleep" "api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [google_project_service.bootstrap_apis]
}

resource "google_storage_bucket" "tfstate" {
  project                     = var.project_id
  name                        = "${local.bucket_prefix}-tfstate"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90
      num_newer_versions         = 10
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [time_sleep.api_propagation]
}

resource "google_storage_bucket" "iac_outputs" {
  project                     = var.project_id
  name                        = "${local.bucket_prefix}-iac-outputs"
  location                    = var.region
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = var.force_destroy
  labels                      = var.labels

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      days_since_noncurrent_time = 90
      num_newer_versions         = 10
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [time_sleep.api_propagation]
}

resource "google_service_account" "ci" {
  for_each = var.enable_ci_service_accounts ? local.ci_service_accounts : {}

  project      = var.project_id
  account_id   = each.value.account_id
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [time_sleep.api_propagation]
}

module "github_wif" {
  count  = var.enable_github_wif ? 1 : 0
  source = "../../modules/foundation/github-wif"

  project_id               = var.project_id
  prefix                   = var.prefix
  github_org               = var.github_org
  github_repositories      = var.github_repositories
  allowed_refs             = var.allowed_refs
  allowed_environments     = var.allowed_environments
  service_account_bindings = local.effective_sa_bindings

  depends_on = [time_sleep.api_propagation]
}
