locals {
  project_prefix    = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  audit_project_id  = "${local.project_prefix}-audit"
  trimmed_dr_region = var.dr_region != null ? trimspace(var.dr_region) : ""
  allowed_resource_locations = concat(
    ["in:${var.region}-locations"],
    local.trimmed_dr_region != "" ? ["in:${local.trimmed_dr_region}-locations"] : [],
  )
}

provider "google" {
  region = var.region
}

provider "google" {
  alias                 = "billing_quota"
  project               = local.audit_project_id
  billing_project       = local.audit_project_id
  user_project_override = true
  region                = var.region
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
  project_name    = trimsuffix(substr("${local.project_prefix} Audit FinOps", 0, 30), " ")
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
    var.enable_scc_notifications ? ["securitycenter.googleapis.com"] : [],
  )
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
  enable_scc_notifications          = var.enable_scc_notifications
  scc_notification_location         = var.scc_notification_location
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

  depends_on = [time_sleep.audit_api_propagation]
}

module "finops_governance" {
  source = "../../modules/foundation/finops-governance"

  providers = {
    google = google.billing_quota
  }

  audit_project_id           = module.audit_project.project_id
  billing_account            = var.billing_account
  prefix                     = var.prefix
  region                     = var.region
  enable_billing_budget      = var.enable_billing_budget
  budget_project_numbers     = var.budget_project_numbers
  monthly_budget_amount      = var.monthly_budget_amount
  budget_currency_code       = var.budget_currency_code
  delete_contents_on_destroy = var.delete_contents_on_destroy
  labels                     = var.labels

  depends_on = [time_sleep.audit_api_propagation]
}

resource "google_tags_tag_binding" "audit_finops" {
  for_each = var.enable_finops_tag_bindings ? toset(["cost_center.shared", "environment.prod"]) : toset([])
  provider = google.billing_quota

  parent    = "//cloudresourcemanager.googleapis.com/projects/${module.audit_project.project_number}"
  tag_value = module.finops_governance.finops_tag_value_ids[each.value]
}
