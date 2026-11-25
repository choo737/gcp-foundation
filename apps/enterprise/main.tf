provider "google" {
  region = var.region
}

provider "google-beta" {
  region = var.region
}

locals {
  env_short                  = var.environment
  auto_code                  = substr(sha256("${var.billing_account}-${var.prefix}-${var.environment}"), 0, 4)
  effective_project_suffix   = var.project_suffix != "" ? var.project_suffix : (var.auto_unique_suffix ? local.auto_code : "")
  project_suffix_tail        = local.effective_project_suffix != "" ? "-${local.effective_project_suffix}" : ""
  project_env_prefix         = "prj-${local.env_short}"
  env_app_folder_id          = lookup(var.environment_app_folder_ids, var.environment, "")
  trimmed_app_folder_id      = var.app_folder_id != null ? trimspace(var.app_folder_id) : ""
  effective_app_folder_id    = local.env_app_folder_id != "" ? local.env_app_folder_id : local.trimmed_app_folder_id
  effective_vpc_sc_perimeter = var.vpc_sc_perimeter_name != null ? trimspace(var.vpc_sc_perimeter_name) : ""
  app_vpc_sc_ingress_members = distinct(concat(
    [for email in values(module.workload_factory.app_runtime_sa_emails) : "serviceAccount:${email}"],
    [for email in values(module.workload_factory.gke_node_sa_emails) : "serviceAccount:${email}"],
    values(module.workload_factory.compute_service_agent_members),
    values(module.workload_factory.cloudrun_service_agent_members),
    values(module.workload_factory.gke_service_agent_members),
  ))
  app_vpc_sc_target_projects = [for num in values(module.workload_factory.app_project_numbers) : "projects/${num}"]
}

module "workload_factory" {
  source = "../../modules/app/workload-factory"

  applications                = var.applications
  prefix                      = var.prefix
  project_suffix              = local.effective_project_suffix
  environment                 = var.environment
  region                      = var.region
  billing_account             = var.billing_account
  app_folder_id               = local.effective_app_folder_id
  deletion_protection         = var.deletion_protection
  project_deletion_policy     = var.project_deletion_policy
  shared_vpc_host_project_id  = var.shared_vpc_host_project_id
  subnet_id                   = var.subnet_id
  kms_key_id                  = var.kms_key_id
  manage_kms_iam              = var.manage_kms_iam
  shared_artifact_registry_id = var.shared_artifact_registry_id
  app_admins_group            = var.app_admins_group
  finops_tag_value_ids        = var.finops_tag_value_ids
  propagation_wait_seconds    = var.propagation_wait_seconds
  labels                      = var.labels
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "app_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && !var.enforce_vpc_sc ? module.workload_factory.app_project_numbers : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_resource" "app_projects" {
  for_each = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && var.enforce_vpc_sc ? module.workload_factory.app_project_numbers : {}

  perimeter_name = local.effective_vpc_sc_perimeter
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_dry_run_ingress_policy" "app_runtime" {
  count = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && !var.enforce_vpc_sc && length(var.applications) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-apps-ingress"

  ingress_from {
    identities = local.app_vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.app_vpc_sc_target_projects
    operations {
      service_name = "*"
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.app_vpc_sc_ingress_members) > 0 && length(local.app_vpc_sc_target_projects) > 0
      error_message = "VPC-SC ingress policy requires at least one explicit identity and one target project resource so empty lists never permit wildcard perimeter ingress."
    }
  }
}

resource "google_access_context_manager_service_perimeter_ingress_policy" "app_runtime" {
  count = local.effective_vpc_sc_perimeter != "" && var.manage_vpc_sc && var.enforce_vpc_sc && length(var.applications) > 0 ? 1 : 0

  perimeter = local.effective_vpc_sc_perimeter
  title     = "${var.prefix}-${var.environment}-apps-ingress"

  ingress_from {
    identities = local.app_vpc_sc_ingress_members
    sources {
      access_level = "*"
    }
  }

  ingress_to {
    resources = local.app_vpc_sc_target_projects
    operations {
      service_name = "*"
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.app_vpc_sc_ingress_members) > 0 && length(local.app_vpc_sc_target_projects) > 0
      error_message = "VPC-SC ingress policy requires at least one explicit identity and one target project resource so empty lists never permit wildcard perimeter ingress."
    }
  }
}
