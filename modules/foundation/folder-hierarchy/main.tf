locals {
  root_display_name = var.folder_suffix != "" ? "${var.prefix}-${var.folder_suffix}-gcp-foundation" : "${var.prefix}-gcp-foundation"
}

resource "google_folder" "root" {
  count = var.create_root_folder ? 1 : 0

  display_name        = local.root_display_name
  parent              = var.parent_id
  deletion_protection = var.deletion_protection
}

locals {
  top_parent      = var.create_root_folder ? google_folder.root[0].name : var.parent_id
  environment_set = toset(var.environments)
  default_env_key = contains(var.environments, "prod") ? "prod" : (length(var.environments) > 0 ? var.environments[0] : "")
}

resource "google_folder" "shared_infra" {
  display_name        = "01-shared-infrastructure"
  parent              = local.top_parent
  deletion_protection = var.deletion_protection
}

resource "google_folder" "workloads" {
  display_name        = "02-workloads"
  parent              = local.top_parent
  deletion_protection = var.deletion_protection
}

resource "google_folder" "workload" {
  for_each = var.workload_folders

  display_name        = each.value
  parent              = google_folder.workloads.name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "environments" {
  count = length(var.environments) > 0 ? 1 : 0

  display_name        = "02-environments"
  parent              = local.top_parent
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env" {
  for_each = local.environment_set

  display_name        = each.value
  parent              = google_folder.environments[0].name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env_data_platform" {
  for_each = local.environment_set

  display_name        = "data-platform"
  parent              = google_folder.env[each.key].name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env_storage" {
  for_each = local.environment_set

  display_name        = "storage"
  parent              = google_folder.env_data_platform[each.key].name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env_compute" {
  for_each = local.environment_set

  display_name        = "compute"
  parent              = google_folder.env_data_platform[each.key].name
  deletion_protection = var.deletion_protection
}
