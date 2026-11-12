provider "google" {
  region = var.region
}

locals {
  project_prefix   = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  trimmed_folder   = var.folder_id != null ? trimspace(var.folder_id) : ""
  trimmed_shared   = var.shared_infra_folder_id != null ? trimspace(var.shared_infra_folder_id) : ""
  env_folder       = lookup(var.environment_folder_ids, var.environment, "")
  target_folder_id = local.env_folder != "" ? local.env_folder : (local.trimmed_folder != "" ? local.trimmed_folder : local.trimmed_shared)

  trimmed_vpc_sc_audit = var.vpc_sc_audit_project_number != null ? trimspace(var.vpc_sc_audit_project_number) : ""
  trimmed_audit_num    = var.audit_project_number != null ? trimspace(var.audit_project_number) : ""
  effective_audit_num  = local.trimmed_vpc_sc_audit != "" ? local.trimmed_vpc_sc_audit : local.trimmed_audit_num

  finops_env_tag_key = var.environment == "prod" ? "environment.prod" : "environment.nonprod"
  project_tag_bindings = merge(
    contains(keys(var.finops_tag_value_ids), "cost_center.shared") ? { cost_center = var.finops_tag_value_ids["cost_center.shared"] } : {},
    contains(keys(var.finops_tag_value_ids), local.finops_env_tag_key) ? { environment = var.finops_tag_value_ids[local.finops_env_tag_key] } : {},
  )
}

resource "terraform_data" "validate_target_folder" {
  lifecycle {
    precondition {
      condition     = local.target_folder_id != ""
      error_message = "Set environment_folder_ids[environment], folder_id, or shared_infra_folder_id."
    }
  }
}

module "network_project" {
  source = "../../modules/foundation/project-factory"

  project_id      = "${local.project_prefix}-network"
  project_name    = trimsuffix(substr("${local.project_prefix} Network Security", 0, 30), " ")
  folder_id       = local.target_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = merge(var.labels, { environment = var.environment })

  activate_apis = [
    "cloudkms.googleapis.com",
    "compute.googleapis.com",
    "dns.googleapis.com",
    "accesscontextmanager.googleapis.com",
    "monitoring.googleapis.com",
    "logging.googleapis.com",
  ]

  depends_on = [terraform_data.validate_target_folder]
}

resource "time_sleep" "network_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.network_project]
}

module "network_security" {
  source = "../../modules/foundation/network-security"

  project_id                       = module.network_project.project_id
  network_project_number           = module.network_project.project_number
  region                           = var.region
  dr_region                        = var.dr_region
  prefix                           = var.prefix
  environment                      = var.environment
  enable_cmek                      = var.enable_cmek
  kms_protection_level             = var.kms_protection_level
  enable_vpc                       = var.enable_vpc
  enable_shared_vpc_host           = var.enable_shared_vpc_host
  subnet_cidr                      = var.subnet_cidr
  enable_datastream_psc_attachment = var.enable_datastream_psc_attachment
  datastream_nat_subnet_cidr       = var.datastream_nat_subnet_cidr
  datastream_producer_accept_lists = var.datastream_producer_accept_lists
  allowed_private_db_cidrs         = var.allowed_private_db_cidrs
  enable_vpc_flow_logs             = var.enable_vpc_flow_logs
  vpc_flow_logs_sampling           = var.vpc_flow_logs_sampling
  enable_dns_logging               = var.enable_dns_logging
  enable_psc                       = var.enable_psc
  enable_vpc_sc                    = var.enable_vpc_sc
  enforce_vpc_sc                   = var.enforce_vpc_sc
  access_policy_id                 = var.access_policy_id
  perimeter_project_numbers        = var.perimeter_project_numbers
  vpc_sc_ingress_principals        = var.vpc_sc_ingress_principals
  vpc_sc_audit_project_number      = local.effective_audit_num
  vpc_sc_access_level_members      = var.vpc_sc_access_level_members
  labels                           = merge(var.labels, { environment = var.environment })

  depends_on = [time_sleep.network_api_propagation]
}

module "monitoring_alerts" {
  source = "../../modules/foundation/monitoring-alerts"

  project_id              = module.network_project.project_id
  prefix                  = var.prefix
  environment             = var.environment
  enable_alerts           = var.enable_alerts
  alert_email_addresses   = var.alert_email_addresses
  alert_pubsub_topic_id   = var.alert_pubsub_topic_id
  dlq_backlog_threshold   = var.dlq_backlog_threshold
  bigquery_slot_threshold = var.bigquery_slot_threshold
  labels                  = merge(var.labels, { environment = var.environment })

  depends_on = [time_sleep.network_api_propagation]
}
