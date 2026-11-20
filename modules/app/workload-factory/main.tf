locals {
  project_prefix            = var.project_suffix != "" ? "${var.prefix}-${var.project_suffix}" : var.prefix
  env_labels                = merge(var.labels, { cost_center = "app", environment = var.environment })
  trimmed_app_folder_id     = var.app_folder_id != null ? trimspace(var.app_folder_id) : ""
  clean_app_folder_id       = local.trimmed_app_folder_id != "" ? "folders/${replace(local.trimmed_app_folder_id, "folders/", "")}" : ""
  effective_shared_vpc_host = var.shared_vpc_host_project_id != null ? trimspace(var.shared_vpc_host_project_id) : ""
  effective_subnet_id       = var.subnet_id != null ? trimspace(var.subnet_id) : ""
  subnet_parts              = local.effective_subnet_id != "" ? split("/", local.effective_subnet_id) : []
  subnet_name               = length(local.subnet_parts) > 0 ? element(local.subnet_parts, length(local.subnet_parts) - 1) : ""
  effective_kms_key_id      = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek                  = local.effective_kms_key_id != ""
  trimmed_shared_ar         = var.shared_artifact_registry_id != null ? trimspace(var.shared_artifact_registry_id) : ""
  shared_ar_parts           = local.trimmed_shared_ar != "" ? split("/", local.trimmed_shared_ar) : []
  has_shared_ar             = can(regex("^projects/[^/]+/locations/[^/]+/repositories/[^/]+$", local.trimmed_shared_ar))

  trimmed_app_admins = var.app_admins_group != null ? trimspace(var.app_admins_group) : ""
  app_admins_member = local.trimmed_app_admins != "" ? (
    startswith(local.trimmed_app_admins, "group:") || startswith(local.trimmed_app_admins, "user:") || startswith(local.trimmed_app_admins, "serviceAccount:")
    ? local.trimmed_app_admins
    : "group:${local.trimmed_app_admins}"
  ) : ""

  finops_env_tag_key = (
    var.environment == "prod"
    ? "environment.prod"
    : (var.environment == "uat" && contains(keys(var.finops_tag_value_ids), "environment.uat") ? "environment.uat" : "environment.nonprod")
  )
  project_tag_bindings = merge(
    contains(keys(var.finops_tag_value_ids), "cost_center.app") ? { cost_center = var.finops_tag_value_ids["cost_center.app"] } : {},
    contains(keys(var.finops_tag_value_ids), local.finops_env_tag_key) ? { environment = var.finops_tag_value_ids[local.finops_env_tag_key] } : {},
  )

  app_project_ids = {
    for k, _ in var.applications : k => "${local.project_prefix}-app-${k}"
  }

  cmek_bindings = local.use_cmek && var.manage_kms_iam ? merge(flatten([
    for k, cfg in var.applications : [
      {
        "${k}|compute" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@compute-system.iam.gserviceaccount.com"
        }
        "${k}|secretmanager" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@gcp-sa-secretmanager.iam.gserviceaccount.com"
        }
      },
      cfg.enable_cloud_run || cfg.enable_gke ? {
        "${k}|artifactregistry" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@gcp-sa-artifactregistry.iam.gserviceaccount.com"
        }
      } : {},
      cfg.enable_cloud_run ? {
        "${k}|cloudrun" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@serverless-robot-prod.iam.gserviceaccount.com"
        }
      } : {},
      cfg.enable_gke ? {
        "${k}|gke" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@container-engine-robot.iam.gserviceaccount.com"
        }
      } : {},
      cfg.enable_cloud_sql ? {
        "${k}|cloudsql" = {
          app_key = k
          member  = "serviceAccount:service-${module.app_project[k].project_number}@gcp-sa-cloud-sql.iam.gserviceaccount.com"
        }
      } : {},
    ]
  ])...) : {}

  shared_ar_readers = local.has_shared_ar ? merge(flatten([
    for k, cfg in var.applications : [
      {
        "${k}|compute" = "serviceAccount:service-${module.app_project[k].project_number}@compute-system.iam.gserviceaccount.com"
        "${k}|runtime" = google_service_account.app_runtime[k].member
      },
      cfg.enable_cloud_run ? {
        "${k}|cloudrun" = "serviceAccount:service-${module.app_project[k].project_number}@serverless-robot-prod.iam.gserviceaccount.com"
      } : {},
      cfg.enable_gke ? {
        "${k}|gke"      = "serviceAccount:service-${module.app_project[k].project_number}@container-engine-robot.iam.gserviceaccount.com"
        "${k}|gke_node" = "serviceAccount:${module.app_project[k].project_number}-compute@developer.gserviceaccount.com"
      } : {},
    ]
  ])...) : {}

  raw_app_iam_entries = flatten([
    for k, cfg in var.applications : concat(
      [
        for m in distinct(compact([
          local.app_admins_member,
          trimspace(cfg.admin_group) != "" ? (
            startswith(trimspace(cfg.admin_group), "group:") || startswith(trimspace(cfg.admin_group), "user:") || startswith(trimspace(cfg.admin_group), "serviceAccount:")
            ? trimspace(cfg.admin_group)
            : "group:${trimspace(cfg.admin_group)}"
          ) : "",
          ])) : [
          for role in concat(
            ["roles/viewer", "roles/monitoring.viewer", "roles/logging.viewer"],
            var.environment != "prod" ? concat(
              ["roles/secretmanager.secretAccessor"],
              cfg.enable_cloud_run ? ["roles/run.admin"] : [],
              cfg.enable_gke ? ["roles/container.admin"] : [],
            ) : [],
            ) : {
            app_key = k
            role    = role
            member  = m
          }
        ]
      ],
      [
        for m in distinct(compact([
          trimspace(cfg.developer_group) != "" ? (
            startswith(trimspace(cfg.developer_group), "group:") || startswith(trimspace(cfg.developer_group), "user:") || startswith(trimspace(cfg.developer_group), "serviceAccount:")
            ? trimspace(cfg.developer_group)
            : "group:${trimspace(cfg.developer_group)}"
          ) : "",
          trimspace(lookup(cfg.env_groups, var.environment, "")) != "" ? (
            startswith(trimspace(lookup(cfg.env_groups, var.environment, "")), "group:") || startswith(trimspace(lookup(cfg.env_groups, var.environment, "")), "user:") || startswith(trimspace(lookup(cfg.env_groups, var.environment, "")), "serviceAccount:")
            ? trimspace(lookup(cfg.env_groups, var.environment, ""))
            : "group:${trimspace(lookup(cfg.env_groups, var.environment, ""))}"
          ) : "",
          ])) : [
          for role in(
            var.environment != "prod"
            ? concat(
              ["roles/logging.viewer", "roles/monitoring.viewer"],
              cfg.enable_cloud_run ? ["roles/run.developer"] : [],
              cfg.enable_gke ? ["roles/container.developer"] : [],
              cfg.enable_cloud_sql ? ["roles/cloudsql.client"] : [],
            )
            : ["roles/logging.viewer", "roles/monitoring.viewer"]
            ) : {
            app_key = k
            role    = role
            member  = m
          }
        ]
      ],
    )
  ])

  app_iam_bindings = {
    for item in local.raw_app_iam_entries :
    "${item.app_key}|${item.role}|${item.member}" => item
  }
}

resource "terraform_data" "validate_app_inputs" {
  count = length(var.applications) > 0 ? 1 : 0

  lifecycle {
    precondition {
      condition     = local.clean_app_folder_id != ""
      error_message = "app_folder_id must be non-empty when applications is non-empty."
    }

    precondition {
      condition     = alltrue([for _, pid in local.app_project_ids : length(pid) <= 30])
      error_message = "Every <prefix>-<suffix>-app-<app_key> project ID must stay within 30 characters."
    }
  }
}

resource "google_folder" "app_unit" {
  for_each = var.applications

  display_name        = each.value.display_name
  parent              = local.clean_app_folder_id
  deletion_protection = var.deletion_protection

  depends_on = [terraform_data.validate_app_inputs]
}

module "app_project" {
  for_each = var.applications
  source   = "../../foundation/project-factory"

  project_id      = local.app_project_ids[each.key]
  project_name    = trimsuffix(substr("${local.project_prefix} App ${each.value.display_name}", 0, 30), " ")
  folder_id       = google_folder.app_unit[each.key].name
  billing_account = var.billing_account
  deletion_policy = var.project_deletion_policy
  tag_bindings    = local.project_tag_bindings
  labels          = merge(local.env_labels, { cost_center = "app", application = each.key })

  activate_apis = toset(concat(
    [
      "compute.googleapis.com",
      "iam.googleapis.com",
      "secretmanager.googleapis.com",
      "logging.googleapis.com",
      "monitoring.googleapis.com",
    ],
    each.value.enable_cloud_run ? ["run.googleapis.com"] : [],
    each.value.enable_gke ? ["container.googleapis.com"] : [],
    each.value.enable_cloud_run || each.value.enable_gke ? ["artifactregistry.googleapis.com"] : [],
    each.value.enable_cloud_sql ? ["sqladmin.googleapis.com"] : [],
  ))

  depends_on = [terraform_data.validate_app_inputs]
}

resource "time_sleep" "app_api_propagation" {
  count = length(var.applications) > 0 ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [module.app_project]
}

resource "google_service_account" "app_runtime" {
  for_each = var.applications

  project      = module.app_project[each.key].project_id
  account_id   = trimsuffix(substr(lower("sa-${each.key}-rt"), 0, 30), "-")
  display_name = "${each.value.display_name} Runtime"
  description  = "Dedicated least-privilege runtime service account for ${each.key} workloads."

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_iam_member" "app_runtime_log_writer" {
  for_each = var.applications

  project = module.app_project[each.key].project_id
  role    = "roles/logging.logWriter"
  member  = google_service_account.app_runtime[each.key].member
}

resource "google_project_iam_member" "app_runtime_metric_writer" {
  for_each = var.applications

  project = module.app_project[each.key].project_id
  role    = "roles/monitoring.metricWriter"
  member  = google_service_account.app_runtime[each.key].member
}

resource "google_compute_shared_vpc_service_project" "app" {
  for_each = local.effective_shared_vpc_host != "" ? var.applications : {}

  host_project    = local.effective_shared_vpc_host
  service_project = module.app_project[each.key].project_id

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "artifactregistry" {
  for_each = { for k, v in var.applications : k => v if v.enable_cloud_run || v.enable_gke }
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "artifactregistry.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "cloudrun" {
  for_each = { for k, v in var.applications : k => v if v.enable_cloud_run }
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "run.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "compute" {
  for_each = { for k, v in var.applications : k => v if v.enable_gke }
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "compute.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "gke" {
  for_each = { for k, v in var.applications : k => v if v.enable_gke }
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "container.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "secretmanager" {
  for_each = local.use_cmek && var.manage_kms_iam ? var.applications : {}
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "secretmanager.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_project_service_identity" "sqladmin" {
  for_each = { for k, v in var.applications : k => v if local.use_cmek && var.manage_kms_iam && v.enable_cloud_sql }
  provider = google-beta

  project = module.app_project[each.key].project_id
  service = "sqladmin.googleapis.com"

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_compute_subnetwork_iam_member" "cloudrun_network_user" {
  for_each = local.effective_shared_vpc_host != "" && local.subnet_name != "" ? {
    for k, v in var.applications : k => v if v.enable_cloud_run
  } : {}

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = local.subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${module.app_project[each.key].project_number}@serverless-robot-prod.iam.gserviceaccount.com"

  depends_on = [
    google_compute_shared_vpc_service_project.app,
    google_project_service_identity.cloudrun,
  ]
}

resource "google_compute_subnetwork_iam_member" "gke_cloudservices_network_user" {
  for_each = local.effective_shared_vpc_host != "" && local.subnet_name != "" ? {
    for k, v in var.applications : k => v if v.enable_gke
  } : {}

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = local.subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:${module.app_project[each.key].project_number}@cloudservices.gserviceaccount.com"

  depends_on = [
    google_compute_shared_vpc_service_project.app,
    google_project_service_identity.gke,
  ]
}

resource "google_compute_subnetwork_iam_member" "gke_robot_network_user" {
  for_each = local.effective_shared_vpc_host != "" && local.subnet_name != "" ? {
    for k, v in var.applications : k => v if v.enable_gke
  } : {}

  project    = local.effective_shared_vpc_host
  region     = var.region
  subnetwork = local.subnet_name
  role       = "roles/compute.networkUser"
  member     = "serviceAccount:service-${module.app_project[each.key].project_number}@container-engine-robot.iam.gserviceaccount.com"

  depends_on = [
    google_compute_shared_vpc_service_project.app,
    google_project_service_identity.gke,
  ]
}

resource "google_project_iam_member" "gke_host_service_agent_user" {
  for_each = local.effective_shared_vpc_host != "" ? {
    for k, v in var.applications : k => v if v.enable_gke
  } : {}

  project = local.effective_shared_vpc_host
  role    = "roles/container.hostServiceAgentUser"
  member  = "serviceAccount:service-${module.app_project[each.key].project_number}@container-engine-robot.iam.gserviceaccount.com"

  depends_on = [
    google_compute_shared_vpc_service_project.app,
    google_project_service_identity.gke,
  ]
}

resource "google_kms_crypto_key_iam_member" "app_cmek" {
  for_each = local.cmek_bindings

  crypto_key_id = local.effective_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = each.value.member

  depends_on = [
    time_sleep.app_api_propagation,
    google_project_service_identity.artifactregistry,
    google_project_service_identity.compute,
    google_project_service_identity.cloudrun,
    google_project_service_identity.gke,
    google_project_service_identity.secretmanager,
    google_project_service_identity.sqladmin,
  ]
}

resource "google_project_iam_member" "app_team_iam" {
  for_each = local.app_iam_bindings

  project = module.app_project[each.value.app_key].project_id
  role    = each.value.role
  member  = each.value.member

  depends_on = [time_sleep.app_api_propagation]
}

resource "google_artifact_registry_repository_iam_member" "shared_golden_reader" {
  for_each = local.shared_ar_readers

  project    = local.shared_ar_parts[1]
  location   = local.shared_ar_parts[3]
  repository = local.shared_ar_parts[5]
  role       = "roles/artifactregistry.reader"
  member     = each.value

  depends_on = [
    time_sleep.app_api_propagation,
    google_service_account.app_runtime,
    google_project_service_identity.artifactregistry,
    google_project_service_identity.compute,
    google_project_service_identity.cloudrun,
    google_project_service_identity.gke,
  ]
}
