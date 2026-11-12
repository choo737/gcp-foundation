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

  depends_on = [time_sleep.api_propagation]
}

module "github_wif" {
  count  = var.enable_github_wif ? 1 : 0
  source = "../../modules/foundation/github-wif"

  project_id               = var.project_id
  prefix                   = var.prefix
  github_org               = var.github_org
  github_repositories      = var.github_repositories
  service_account_bindings = var.service_account_bindings

  depends_on = [time_sleep.api_propagation]
}
