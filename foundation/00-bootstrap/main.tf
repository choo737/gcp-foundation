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

  use_per_stage_sas = (
    var.foundation_sa_mode == "per_stage" ||
    contains(keys(var.ci_repository_map), "org_gov_ci") ||
    contains(keys(var.ci_repository_map), "net_sec_ci") ||
    contains(keys(var.ci_repository_map), "data_plat_ci")
  )

  include_tf_foundation_ci = (
    var.foundation_sa_mode == "single" ||
    contains(keys(var.ci_repository_map), "tf_foundation_ci")
  )

  include_tf_ds_ci = contains(keys(var.ci_repository_map), "tf_ds_ci")

  ci_service_accounts = merge(
    local.include_tf_foundation_ci ? {
      tf_foundation_ci = {
        account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-tf-foundation-ci"), 0, 30), "-")
        display_name = "${var.prefix} Foundation CI"
        description  = "Service account for GitHub Actions gcp-foundation Terraform runs."
      }
    } : {},
    local.use_per_stage_sas ? {
      org_gov_ci = {
        account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-org-gov-ci"), 0, 30), "-")
        display_name = "${var.prefix} Org Governance CI"
        description  = "Service account for GitHub Actions foundation/01-org-governance runs."
      }
      net_sec_ci = {
        account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-net-sec-ci"), 0, 30), "-")
        display_name = "${var.prefix} Network Security CI"
        description  = "Service account for GitHub Actions foundation/02-security-network runs."
      }
      data_plat_ci = {
        account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-data-plat-ci"), 0, 30), "-")
        display_name = "${var.prefix} Data Platform CI"
        description  = "Service account for GitHub Actions data/enterprise runs."
      }
    } : {},
    local.include_tf_ds_ci ? {
      tf_ds_ci = {
        account_id   = trimsuffix(substr(lower("${replace(var.prefix, "_", "-")}-tf-ds-ci"), 0, 30), "-")
        display_name = "${var.prefix} Data Science CI"
        description  = "Service account for GitHub Actions gcp-data-science and 03-data-science Terraform runs."
      }
    } : {},
    {
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
    },
  )

  scoped_tfstate_prefixes = {
    for k, prefix in {
      org_gov_ci      = "foundation/01-org-governance/"
      net_sec_ci      = "foundation/02-security-network/"
      data_plat_ci    = "data/"
      tf_ingestion_ci = "ingestion/"
      tf_ds_ci        = "data-science/"
    } : k => prefix
    if var.enable_ci_service_accounts && contains(keys(local.ci_service_accounts), k)
  }

  iac_outputs_admin_sas = toset([
    for k in ["tf_foundation_ci", "org_gov_ci", "net_sec_ci", "data_plat_ci"] : k
    if var.enable_ci_service_accounts && contains(keys(local.ci_service_accounts), k)
  ])

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

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
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

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
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

resource "google_storage_bucket_iam_member" "tfstate_foundation_admin" {
  count = var.enable_ci_service_accounts && local.include_tf_foundation_ci ? 1 : 0

  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci["tf_foundation_ci"].member
}

resource "google_storage_bucket_iam_member" "tfstate_scoped_admin" {
  for_each = local.scoped_tfstate_prefixes

  bucket = google_storage_bucket.tfstate.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci[each.key].member

  condition {
    title       = "${each.key}_tfstate_prefix"
    description = "Restrict Terraform state access to ${each.value} prefix."
    expression  = "(resource.type == \"storage.googleapis.com/Bucket\" && (api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"${each.value}\") || api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\") == \"${trimsuffix(each.value, "/")}\")) || (resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.tfstate.name}/objects/${each.value}\"))"
  }
}

resource "google_storage_bucket_iam_member" "iac_outputs_foundation_admin" {
  for_each = local.iac_outputs_admin_sas

  bucket = google_storage_bucket.iac_outputs.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci[each.key].member
}

resource "google_storage_bucket_iam_member" "iac_outputs_ingestion_viewer" {
  count = var.enable_ci_service_accounts ? 1 : 0

  bucket = google_storage_bucket.iac_outputs.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ci["tf_ingestion_ci"].member
}

resource "google_storage_bucket_iam_member" "iac_outputs_ingestion_prefix_admin" {
  count = var.enable_ci_service_accounts ? 1 : 0

  bucket = google_storage_bucket.iac_outputs.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci["tf_ingestion_ci"].member

  condition {
    title       = "tf_ingestion_ci_outputs_prefix"
    description = "Allow ingestion CI to export outputs under ingestion/ prefix."
    expression  = "(resource.type == \"storage.googleapis.com/Bucket\" && (api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"ingestion/\") || api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\") == \"ingestion\")) || (resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.iac_outputs.name}/objects/ingestion/\"))"
  }
}

resource "google_storage_bucket_iam_member" "iac_outputs_ds_viewer" {
  count = var.enable_ci_service_accounts && local.include_tf_ds_ci ? 1 : 0

  bucket = google_storage_bucket.iac_outputs.name
  role   = "roles/storage.objectViewer"
  member = google_service_account.ci["tf_ds_ci"].member
}

resource "google_storage_bucket_iam_member" "iac_outputs_ds_prefix_admin" {
  count = var.enable_ci_service_accounts && local.include_tf_ds_ci ? 1 : 0

  bucket = google_storage_bucket.iac_outputs.name
  role   = "roles/storage.objectAdmin"
  member = google_service_account.ci["tf_ds_ci"].member

  condition {
    title       = "tf_ds_ci_outputs_prefix"
    description = "Allow data science CI to export outputs under data-science/ prefix."
    expression  = "(resource.type == \"storage.googleapis.com/Bucket\" && (api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"data-science/\") || api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\") == \"data-science\")) || (resource.type == \"storage.googleapis.com/Object\" && resource.name.startsWith(\"projects/_/buckets/${google_storage_bucket.iac_outputs.name}/objects/data-science/\"))"
  }
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
