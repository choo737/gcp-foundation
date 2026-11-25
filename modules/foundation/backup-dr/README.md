# Backup and DR Module

This module provisions a central Google Cloud Backup and DR vault and daily backup plans.

## Resources Managed

- `google_backup_dr_backup_vault` with enforced minimum retention, optional vault lock, and optional CMEK.
- Optional daily `google_backup_dr_backup_plan` schedules for Compute Engine (`compute.googleapis.com/Instance`).
- Optional daily `google_backup_dr_backup_plan` schedules for Cloud SQL (`sqladmin.googleapis.com/Instance`).
- Optional `roles/backupdr.user` IAM bindings on the backup project.

## Usage

```hcl
module "backup_dr" {
  source = "../../modules/foundation/backup-dr"

  backup_project_id       = module.backup_project[0].project_id
  region                  = var.region
  prefix                  = var.prefix
  enforced_retention_days = 14
}
```
