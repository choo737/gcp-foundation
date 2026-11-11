provider "google" {
  region = var.region
}

locals {
  project_prefix = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
}

module "network_project" {
  source = "../../modules/foundation/project-factory"

  project_id      = "${local.project_prefix}-network"
  project_name    = trimsuffix(substr("${local.project_prefix} Network Security", 0, 30), " ")
  folder_id       = var.shared_infra_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "accesscontextmanager.googleapis.com",
  ]
}

resource "time_sleep" "network_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.network_project]
}

module "network_security" {
  source = "../../modules/foundation/network-security"

  project_id                = module.network_project.project_id
  region                    = var.region
  prefix                    = var.prefix
  enable_cmek               = var.enable_cmek
  kms_protection_level      = var.kms_protection_level
  enable_vpc                = var.enable_vpc
  enable_psc                = var.enable_psc
  enable_vpc_sc             = var.enable_vpc_sc
  enforce_vpc_sc            = var.enforce_vpc_sc
  access_policy_id          = var.access_policy_id
  perimeter_project_numbers = var.perimeter_project_numbers
  labels                    = var.labels

  depends_on = [time_sleep.network_api_propagation]
}
