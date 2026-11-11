resource "google_project" "this" {
  project_id          = var.project_id
  name                = var.project_name != "" ? var.project_name : var.project_id
  folder_id           = replace(var.folder_id, "folders/", "")
  billing_account     = var.billing_account
  auto_create_network = false
  deletion_policy     = var.deletion_policy
  labels              = var.labels
}

resource "google_project_service" "apis" {
  for_each = var.activate_apis

  project                    = google_project.this.project_id
  service                    = each.value
  disable_on_destroy         = false
  disable_dependent_services = false
}

resource "google_service_account" "this" {
  for_each = var.service_accounts

  project      = google_project.this.project_id
  account_id   = each.key
  display_name = each.value.display_name
  description  = each.value.description

  depends_on = [google_project_service.apis]
}

resource "google_project_iam_member" "this" {
  for_each = var.project_iam_bindings

  project = google_project.this.project_id
  role    = each.value.role
  member  = each.value.member
}
