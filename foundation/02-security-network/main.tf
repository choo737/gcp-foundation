provider "google" {
  region = var.region
}

locals {
  auto_code                = substr(sha256("${var.billing_account}-${var.prefix}-${var.environment}"), 0, 4)
  effective_project_suffix = var.project_suffix != "" ? var.project_suffix : (var.auto_unique_suffix ? local.auto_code : "")
  project_prefix           = local.effective_project_suffix != "" ? "${var.prefix}-${local.effective_project_suffix}" : var.prefix
  trimmed_folder           = var.folder_id != null ? trimspace(var.folder_id) : ""
  trimmed_shared           = var.shared_infra_folder_id != null ? trimspace(var.shared_infra_folder_id) : ""
  env_folder               = lookup(var.environment_folder_ids, var.environment, "")
  env_network_folder       = lookup(var.environment_network_folder_ids, var.environment, "")
  target_folder_id         = local.env_network_folder != "" ? local.env_network_folder : (local.env_folder != "" ? local.env_folder : (local.trimmed_folder != "" ? local.trimmed_folder : local.trimmed_shared))

  trimmed_network_admins = var.network_admins_group != null ? trimspace(var.network_admins_group) : ""
  network_admins_member = local.trimmed_network_admins != "" ? (
    startswith(local.trimmed_network_admins, "group:") || startswith(local.trimmed_network_admins, "user:") || startswith(local.trimmed_network_admins, "serviceAccount:")
    ? local.trimmed_network_admins
    : "group:${local.trimmed_network_admins}"
  ) : ""

  trimmed_security_admins = var.security_admins_group != null ? trimspace(var.security_admins_group) : ""
  security_admins_member = local.trimmed_security_admins != "" ? (
    startswith(local.trimmed_security_admins, "group:") || startswith(local.trimmed_security_admins, "user:") || startswith(local.trimmed_security_admins, "serviceAccount:")
    ? local.trimmed_security_admins
    : "group:${local.trimmed_security_admins}"
  ) : ""

  trimmed_vpc_sc_audit  = var.vpc_sc_audit_project_number != null ? trimspace(var.vpc_sc_audit_project_number) : ""
  trimmed_audit_num     = var.audit_project_number != null ? trimspace(var.audit_project_number) : ""
  effective_audit_num   = local.trimmed_vpc_sc_audit != "" ? local.trimmed_vpc_sc_audit : local.trimmed_audit_num
  trimmed_vpc_sc_secops = var.vpc_sc_secops_project_number != null ? trimspace(var.vpc_sc_secops_project_number) : ""
  trimmed_secops_num    = var.secops_project_number != null ? trimspace(var.secops_project_number) : ""
  effective_secops_num  = local.trimmed_vpc_sc_secops != "" ? local.trimmed_vpc_sc_secops : local.trimmed_secops_num

  finops_env_tag_key = (
    var.environment == "prod"
    ? "environment.prod"
    : (var.environment == "uat" && contains(keys(var.finops_tag_value_ids), "environment.uat") ? "environment.uat" : "environment.nonprod")
  )
  env_labels         = merge(var.labels, { cost_center = "network", environment = var.environment })
  cost_center_tag_id = lookup(var.finops_tag_value_ids, "cost_center.network", lookup(var.finops_tag_value_ids, "cost_center.shared", ""))
  project_tag_bindings = merge(
    local.cost_center_tag_id != "" ? { cost_center = local.cost_center_tag_id } : {},
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
  labels          = local.env_labels

  activate_apis = concat(
    [
      "cloudkms.googleapis.com",
      "compute.googleapis.com",
      "dns.googleapis.com",
      "accesscontextmanager.googleapis.com",
      "monitoring.googleapis.com",
      "logging.googleapis.com",
    ],
    var.enable_ngfw_enterprise ? ["networksecurity.googleapis.com"] : [],
  )

  depends_on = [terraform_data.validate_target_folder]
}

resource "time_sleep" "network_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.network_project]
}

module "network_security" {
  source = "../../modules/foundation/network-security"

  project_id                          = module.network_project.project_id
  network_project_number              = module.network_project.project_number
  region                              = var.region
  dr_region                           = var.dr_region
  prefix                              = var.prefix
  environment                         = var.environment
  enable_cmek                         = var.enable_cmek
  kms_protection_level                = var.kms_protection_level
  allowed_cmek_service_agents         = var.allowed_cmek_service_agents
  enable_vpc                          = var.enable_vpc
  enable_shared_vpc_host              = var.enable_shared_vpc_host
  subnet_cidr                         = var.subnet_cidr
  department_subnet_cidrs             = var.department_subnet_cidrs
  department_subnet_secondary_ranges  = var.department_subnet_secondary_ranges
  enable_datastream_psc_attachment    = var.enable_datastream_psc_attachment
  datastream_nat_subnet_cidr          = var.datastream_nat_subnet_cidr
  datastream_producer_accept_lists    = var.datastream_producer_accept_lists
  allowed_private_db_cidrs            = var.allowed_private_db_cidrs
  enable_vpc_flow_logs                = var.enable_vpc_flow_logs
  vpc_flow_logs_sampling              = var.vpc_flow_logs_sampling
  enable_dns_logging                  = var.enable_dns_logging
  enable_psc                          = var.enable_psc
  enable_vpc_sc                       = var.enable_vpc_sc
  enforce_vpc_sc                      = var.enforce_vpc_sc
  access_policy_id                    = var.access_policy_id
  perimeter_project_numbers           = var.perimeter_project_numbers
  vpc_sc_ingress_principals           = var.vpc_sc_ingress_principals
  vpc_sc_audit_project_number         = local.effective_audit_num
  vpc_sc_secops_project_number        = local.effective_secops_num
  vpc_sc_access_level_members         = var.vpc_sc_access_level_members
  enable_hierarchical_firewall_policy = var.enable_hierarchical_firewall_policy
  firewall_policy_folder_id           = local.env_folder
  enable_ngfw_standard_rules          = var.enable_ngfw_standard_rules
  threat_intelligence_lists           = var.threat_intelligence_lists
  enable_iap_ssh_ingress              = var.enable_iap_ssh_ingress
  enable_secure_tags                  = var.enable_secure_tags
  allowed_egress_fqdns                = var.allowed_egress_fqdns
  enable_ngfw_enterprise              = var.enable_ngfw_enterprise
  organization_id                     = var.organization_id
  ngfw_enterprise_zones               = var.ngfw_enterprise_zones
  enable_ngfw_tls_inspection          = var.enable_ngfw_tls_inspection
  ngfw_tls_inspection_policy_id       = var.ngfw_tls_inspection_policy_id
  labels                              = local.env_labels

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
  labels                  = local.env_labels

  depends_on = [time_sleep.network_api_propagation]
}

resource "google_project_iam_member" "network_admins_network" {
  count = local.network_admins_member != "" ? 1 : 0

  project = module.network_project.project_id
  role    = "roles/compute.networkAdmin"
  member  = local.network_admins_member

  depends_on = [time_sleep.network_api_propagation]
}

resource "google_project_iam_member" "network_admins_dns" {
  count = local.network_admins_member != "" ? 1 : 0

  project = module.network_project.project_id
  role    = "roles/dns.admin"
  member  = local.network_admins_member

  depends_on = [time_sleep.network_api_propagation]
}

resource "google_project_iam_member" "security_admins_kms_viewer" {
  count = local.security_admins_member != "" ? 1 : 0

  project = module.network_project.project_id
  role    = "roles/cloudkms.viewer"
  member  = local.security_admins_member

  depends_on = [time_sleep.network_api_propagation]
}
