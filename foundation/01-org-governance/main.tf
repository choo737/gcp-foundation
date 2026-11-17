locals {
  project_prefix             = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  audit_project_id           = "${local.project_prefix}-audit"
  finops_project_id          = "${local.project_prefix}-cmn-finops"
  backup_project_id          = "${local.project_prefix}-cmn-backup"
  effective_finops_project   = var.create_dedicated_finops_project ? module.finops_project[0].project_id : module.audit_project.project_id
  effective_audit_kms_key_id = var.enable_audit_cmek ? google_kms_crypto_key.audit_cmek[0].id : ""

  trimmed_dr_region = var.dr_region != null ? trimspace(var.dr_region) : ""
  allowed_resource_locations = concat(
    ["in:${var.region}-locations"],
    local.trimmed_dr_region != "" ? ["in:${local.trimmed_dr_region}-locations"] : [],
  )

  effective_scc_tier     = var.scc_tier != "NONE" ? var.scc_tier : (var.enable_scc_notifications ? "STANDARD" : "NONE")
  trimmed_scc_loc        = var.scc_location != null ? trimspace(var.scc_location) : ""
  trimmed_legacy_scc_loc = var.scc_notification_location != null ? trimspace(var.scc_notification_location) : ""
  effective_scc_location = (
    local.trimmed_scc_loc != "" && local.trimmed_scc_loc != "global"
    ? local.trimmed_scc_loc
    : (local.trimmed_legacy_scc_loc != "" ? local.trimmed_legacy_scc_loc : "global")
  )
  trimmed_org_id = var.organization_id != null ? trimspace(var.organization_id) : ""
  effective_organization_id = (
    local.trimmed_org_id != ""
    ? local.trimmed_org_id
    : (startswith(var.parent_id, "organizations/") ? var.parent_id : "")
  )
}

provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

provider "google" {
  alias                 = "billing_quota"
  project               = local.audit_project_id
  billing_project       = local.audit_project_id
  user_project_override = true
  region                = var.region
}

resource "terraform_data" "validate_project_id_lengths" {
  lifecycle {
    precondition {
      condition     = length(local.finops_project_id) <= 30 && length(local.backup_project_id) <= 30
      error_message = "Combined prefix and project_suffix must keep -cmn-finops and -cmn-backup project IDs within 30 characters."
    }
  }
}

module "folder_hierarchy" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id           = var.parent_id
  prefix              = var.prefix
  folder_suffix       = var.project_suffix
  create_root_folder  = true
  deletion_protection = var.deletion_protection
  workload_folders    = ["data-platform"]
  environments        = var.environments
}

module "audit_project" {
  source = "../../modules/foundation/project-factory"

  project_id      = local.audit_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Audit SecOps", 0, 30), " ")
  folder_id       = module.folder_hierarchy.shared_infra_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = concat(
    [
      "logging.googleapis.com",
      "orgpolicy.googleapis.com",
      "cloudresourcemanager.googleapis.com",
      "billingbudgets.googleapis.com",
      "pubsub.googleapis.com",
      "bigquery.googleapis.com",
      "essentialcontacts.googleapis.com",
    ],
    var.enable_audit_cmek ? ["cloudkms.googleapis.com"] : [],
    local.effective_scc_tier != "NONE" ? [
      "securitycenter.googleapis.com",
      "monitoring.googleapis.com",
    ] : [],
    local.effective_scc_tier == "PREMIUM" ? concat(
      ["securitycentermanagement.googleapis.com"],
      var.enable_security_posture ? ["securityposture.googleapis.com"] : [],
    ) : [],
  )

  depends_on = [terraform_data.validate_project_id_lengths]
}

resource "time_sleep" "audit_api_propagation" {
  create_duration = var.propagation_wait_seconds

  depends_on = [module.audit_project]
}

resource "google_resource_manager_lien" "audit_project" {
  count    = var.enable_audit_project_lien ? 1 : 0
  provider = google.billing_quota

  parent       = "projects/${module.audit_project.project_number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "${var.prefix}-org-governance"
  reason       = "Locked compliance audit log bucket protection"

  depends_on = [time_sleep.audit_api_propagation]
}

resource "google_kms_key_ring" "audit" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google.billing_quota

  project  = module.audit_project.project_id
  name     = "${var.prefix}-audit-keyring"
  location = var.region

  depends_on = [time_sleep.audit_api_propagation]
}

resource "google_kms_crypto_key" "audit_cmek" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google.billing_quota

  name                       = "${var.prefix}-audit-cmek"
  key_ring                   = google_kms_key_ring.audit[0].id
  purpose                    = "ENCRYPT_DECRYPT"
  rotation_period            = "7776000s"
  destroy_scheduled_duration = "2592000s"
  labels                     = var.labels

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = var.audit_kms_protection_level
  }
}

resource "google_project_service_identity" "audit_bq" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google-beta

  project = module.audit_project.project_id
  service = "bigquery.googleapis.com"

  depends_on = [time_sleep.audit_api_propagation]
}

resource "google_project_service_identity" "audit_pubsub" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google-beta

  project = module.audit_project.project_id
  service = "pubsub.googleapis.com"

  depends_on = [time_sleep.audit_api_propagation]
}

resource "google_kms_crypto_key_iam_member" "audit_bq_cmek" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google.billing_quota

  crypto_key_id = google_kms_crypto_key.audit_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:bq-${module.audit_project.project_number}@bigquery-encryption.iam.gserviceaccount.com"

  depends_on = [google_project_service_identity.audit_bq]
}

resource "google_kms_crypto_key_iam_member" "audit_pubsub_cmek" {
  count    = var.enable_audit_cmek ? 1 : 0
  provider = google.billing_quota

  crypto_key_id = google_kms_crypto_key.audit_cmek[0].id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:service-${module.audit_project.project_number}@gcp-sa-pubsub.iam.gserviceaccount.com"

  depends_on = [google_project_service_identity.audit_pubsub]
}

resource "time_sleep" "audit_cmek_iam_propagation" {
  count = var.enable_audit_cmek ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [
    google_kms_crypto_key_iam_member.audit_bq_cmek,
    google_kms_crypto_key_iam_member.audit_pubsub_cmek,
  ]
}

module "finops_project" {
  count  = var.create_dedicated_finops_project ? 1 : 0
  source = "../../modules/foundation/project-factory"

  project_id      = local.finops_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Common FinOps", 0, 30), " ")
  folder_id       = module.folder_hierarchy.shared_infra_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "bigquery.googleapis.com",
    "billingbudgets.googleapis.com",
    "monitoring.googleapis.com",
    "pubsub.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]

  depends_on = [terraform_data.validate_project_id_lengths]
}

resource "time_sleep" "finops_api_propagation" {
  count = var.create_dedicated_finops_project ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [module.finops_project]
}

resource "google_resource_manager_lien" "finops_project" {
  count    = var.create_dedicated_finops_project && var.enable_audit_project_lien ? 1 : 0
  provider = google.billing_quota

  parent       = "projects/${module.finops_project[0].project_number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "${var.prefix}-org-governance"
  reason       = "Protected FinOps billing export and budget project"

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.finops_api_propagation,
  ]
}

module "backup_project" {
  count  = var.enable_backup_dr ? 1 : 0
  source = "../../modules/foundation/project-factory"

  project_id      = local.backup_project_id
  project_name    = trimsuffix(substr("${local.project_prefix} Common Backup", 0, 30), " ")
  folder_id       = module.folder_hierarchy.shared_infra_folder_id
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  labels          = var.labels

  activate_apis = [
    "backupdr.googleapis.com",
    "compute.googleapis.com",
    "cloudresourcemanager.googleapis.com",
  ]

  depends_on = [terraform_data.validate_project_id_lengths]
}

resource "time_sleep" "backup_api_propagation" {
  count = var.enable_backup_dr ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [module.backup_project]
}

resource "google_resource_manager_lien" "backup_project" {
  count    = var.enable_backup_dr && var.enable_audit_project_lien ? 1 : 0
  provider = google.billing_quota

  parent       = "projects/${module.backup_project[0].project_number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "${var.prefix}-org-governance"
  reason       = "Protected Backup and DR vault project"

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.backup_api_propagation,
  ]
}

module "backup_dr" {
  count  = var.enable_backup_dr ? 1 : 0
  source = "../../modules/foundation/backup-dr"

  providers = {
    google = google.billing_quota
  }

  backup_project_id            = module.backup_project[0].project_id
  region                       = var.region
  prefix                       = var.prefix
  enforced_retention_days      = var.backup_enforced_retention_days
  backup_retention_days        = var.backup_retention_days
  lock_backup_vault            = var.lock_backup_vault
  lock_effective_time          = var.backup_lock_effective_time
  deletion_protection          = var.deletion_protection
  kms_key_id                   = var.backup_kms_key_id
  backup_time_zone             = var.backup_time_zone
  authorized_backup_principals = var.authorized_backup_principals
  labels                       = var.labels

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.backup_api_propagation,
  ]
}

module "logging_guardrails" {
  source = "../../modules/foundation/logging-guardrails"

  providers = {
    google = google.billing_quota
  }

  audit_project_id                  = module.audit_project.project_id
  folder_id                         = module.folder_hierarchy.root_folder_id
  billing_account                   = var.billing_account
  prefix                            = var.prefix
  region                            = var.region
  retention_days                    = var.retention_days
  lock_audit_bucket                 = var.lock_audit_bucket
  enable_log_analytics              = var.enable_log_analytics
  enable_log_analytics_link         = var.enable_log_analytics_link
  enable_folder_sink                = true
  enable_siem_pubsub_sink           = var.enable_siem_pubsub_sink
  siem_kms_key_id                   = local.effective_audit_kms_key_id
  enable_scc_notifications          = false
  scc_notification_location         = local.effective_scc_location
  essential_contacts                = var.essential_contacts
  foundation_iam_groups             = var.foundation_iam_groups
  enable_data_access_audit_logs     = var.enable_data_access_audit_logs
  enable_org_policies               = var.enable_org_policies
  allowed_resource_locations        = local.allowed_resource_locations
  allowed_policy_member_domains     = var.allowed_policy_member_domains
  allowed_contact_domains           = var.allowed_contact_domains
  denied_storage_auth_types         = var.denied_storage_auth_types
  allowed_cloud_run_ingress         = var.allowed_cloud_run_ingress
  allowed_cloud_functions_ingress   = var.allowed_cloud_functions_ingress
  allowed_protocol_forwarding_types = var.allowed_protocol_forwarding_types
  labels                            = var.labels

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.audit_cmek_iam_propagation,
  ]
}

module "finops_governance" {
  source = "../../modules/foundation/finops-governance"

  providers = {
    google = google.billing_quota
  }

  audit_project_id               = module.audit_project.project_id
  finops_project_id              = local.effective_finops_project
  billing_account                = var.billing_account
  prefix                         = var.prefix
  region                         = var.region
  billing_export_location        = var.finops_billing_export_location
  enable_billing_budget          = var.enable_billing_budget
  budget_project_numbers         = var.budget_project_numbers
  monthly_budget_amount          = var.monthly_budget_amount
  budget_currency_code           = var.budget_currency_code
  alert_email_addresses          = var.finops_alert_email_addresses
  environment_budgets            = var.environment_budgets
  environment_folder_ids         = module.folder_hierarchy.environment_folder_ids
  workload_budgets               = var.workload_budgets
  budget_thresholds              = var.budget_thresholds
  enable_forecasted_threshold    = var.enable_forecasted_threshold
  disable_default_iam_recipients = var.disable_default_iam_recipients
  delete_contents_on_destroy     = var.delete_contents_on_destroy
  labels                         = var.labels

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.finops_api_propagation,
  ]
}

resource "google_tags_tag_binding" "audit_finops" {
  for_each = var.enable_finops_tag_bindings ? toset(["cost_center.shared", "environment.prod"]) : toset([])
  provider = google.billing_quota

  parent    = "//cloudresourcemanager.googleapis.com/projects/${module.audit_project.project_number}"
  tag_value = module.finops_governance.finops_tag_value_ids[each.value]
}

resource "google_tags_tag_binding" "finops_project" {
  for_each = var.create_dedicated_finops_project && var.enable_finops_tag_bindings ? toset(["cost_center.shared", "environment.prod"]) : toset([])
  provider = google.billing_quota

  parent    = "//cloudresourcemanager.googleapis.com/projects/${module.finops_project[0].project_number}"
  tag_value = module.finops_governance.finops_tag_value_ids[each.value]
}

module "scc_secops" {
  source = "../../modules/foundation/scc-secops"

  providers = {
    google = google.billing_quota
  }

  scc_tier                   = local.effective_scc_tier
  scc_scope                  = var.scc_scope
  scc_target_project_ids     = var.scc_target_project_ids
  scc_location               = local.effective_scc_location
  folder_id                  = module.folder_hierarchy.root_folder_id
  environment_folder_ids     = module.folder_hierarchy.environment_folder_ids
  audit_project_id           = module.audit_project.project_id
  kms_key_id                 = local.effective_audit_kms_key_id
  prefix                     = var.prefix
  region                     = var.region
  delete_contents_on_destroy = var.delete_contents_on_destroy
  alert_email_addresses      = var.scc_alert_email_addresses
  siem_push_endpoint         = var.scc_siem_push_endpoint
  enable_custom_etd_module   = var.enable_custom_etd_module
  custom_etd_config_json     = var.custom_etd_config_json
  enable_security_posture    = var.enable_security_posture
  organization_id            = local.effective_organization_id
  labels                     = var.labels

  depends_on = [
    time_sleep.audit_api_propagation,
    time_sleep.audit_cmek_iam_propagation,
  ]
}
