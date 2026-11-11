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
  top_parent = var.create_root_folder ? google_folder.root[0].name : var.parent_id
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
