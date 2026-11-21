locals {
  environment_set = toset(var.environments)
  default_env_key = contains(var.environments, "prod") ? "prod" : (length(var.environments) > 0 ? var.environments[0] : "")
}

resource "google_folder" "shared_infra" {
  display_name        = "shared-infrastructure"
  parent              = var.parent_id
  deletion_protection = var.deletion_protection
}

resource "google_folder" "environments" {
  count = length(var.environments) > 0 ? 1 : 0

  display_name        = "environments"
  parent              = var.parent_id
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

resource "google_folder" "env_ai" {
  for_each = local.environment_set

  display_name        = "ai"
  parent              = google_folder.env[each.key].name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env_app" {
  for_each = local.environment_set

  display_name        = "app"
  parent              = google_folder.env[each.key].name
  deletion_protection = var.deletion_protection
}

resource "google_folder" "env_network" {
  for_each = local.environment_set

  display_name        = "network"
  parent              = google_folder.env[each.key].name
  deletion_protection = var.deletion_protection
}
