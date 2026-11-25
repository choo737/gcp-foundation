locals {
  trimmed_kms_key_id             = var.kms_key_id != null ? trimspace(var.kms_key_id) : ""
  use_cmek                       = local.trimmed_kms_key_id != ""
  trimmed_lock_effective_time    = var.lock_effective_time != null ? trimspace(var.lock_effective_time) : ""
  effective_backup_retention_day = max(var.backup_retention_days, var.enforced_retention_days)
  vault_id                       = "${var.prefix}-vault"
}

resource "google_project_service_identity" "backupdr" {
  count    = local.use_cmek && var.manage_kms_iam ? 1 : 0
  provider = google-beta

  project = var.backup_project_id
  service = "backupdr.googleapis.com"
}

resource "google_kms_crypto_key_iam_member" "backupdr_cmek" {
  count = local.use_cmek && var.manage_kms_iam ? 1 : 0

  crypto_key_id = local.trimmed_kms_key_id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = google_project_service_identity.backupdr[0].member
}

resource "time_sleep" "backupdr_cmek_propagation" {
  count = local.use_cmek && var.manage_kms_iam ? 1 : 0

  create_duration = var.propagation_wait_seconds

  depends_on = [google_kms_crypto_key_iam_member.backupdr_cmek]
}

resource "google_backup_dr_backup_vault" "primary" {
  project                                    = var.backup_project_id
  location                                   = var.region
  backup_vault_id                            = local.vault_id
  description                                = "Immutable Backup and DR vault for governed workloads."
  backup_minimum_enforced_retention_duration = "${var.enforced_retention_days * 86400}s"
  access_restriction                         = var.access_restriction
  effective_time                             = var.lock_backup_vault && local.trimmed_lock_effective_time != "" ? local.trimmed_lock_effective_time : null
  force_delete                               = !var.deletion_protection
  ignore_inactive_datasources                = !var.deletion_protection
  ignore_backup_plan_references              = !var.deletion_protection
  labels                                     = var.labels

  dynamic "encryption_config" {
    for_each = local.trimmed_kms_key_id != "" ? [local.trimmed_kms_key_id] : []
    content {
      kms_key_name = encryption_config.value
    }
  }

  lifecycle {
    precondition {
      condition     = !var.lock_backup_vault || local.trimmed_lock_effective_time != ""
      error_message = "lock_effective_time must be an RFC3339 timestamp when lock_backup_vault is true."
    }
  }

  depends_on = [time_sleep.backupdr_cmek_propagation]
}

resource "google_backup_dr_backup_plan" "gce" {
  count = var.enable_gce_backup_plan ? 1 : 0

  project        = var.backup_project_id
  location       = var.region
  backup_plan_id = "${var.prefix}-gce-daily"
  description    = "Daily Compute Engine VM backup plan."
  resource_type  = "compute.googleapis.com/Instance"
  backup_vault   = google_backup_dr_backup_vault.primary.id
  labels         = var.labels

  backup_rules {
    rule_id               = "daily-gce-backup"
    backup_retention_days = local.effective_backup_retention_day

    standard_schedule {
      recurrence_type = "DAILY"
      time_zone       = var.backup_time_zone

      backup_window {
        start_hour_of_day = 2
        end_hour_of_day   = 6
      }
    }
  }
}

resource "google_backup_dr_backup_plan" "cloudsql" {
  count = var.enable_cloudsql_backup_plan ? 1 : 0

  project        = var.backup_project_id
  location       = var.region
  backup_plan_id = "${var.prefix}-cloudsql-daily"
  description    = "Daily Cloud SQL instance backup plan."
  resource_type  = "sqladmin.googleapis.com/Instance"
  backup_vault   = google_backup_dr_backup_vault.primary.id
  labels         = var.labels

  backup_rules {
    rule_id               = "daily-cloudsql-backup"
    backup_retention_days = local.effective_backup_retention_day

    standard_schedule {
      recurrence_type = "DAILY"
      time_zone       = var.backup_time_zone

      backup_window {
        start_hour_of_day = 2
        end_hour_of_day   = 6
      }
    }
  }
}

resource "google_project_iam_member" "backup_users" {
  for_each = toset(var.authorized_backup_principals)

  project = var.backup_project_id
  role    = "roles/backupdr.user"
  member  = each.value
}
