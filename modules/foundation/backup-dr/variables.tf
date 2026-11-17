variable "backup_project_id" {
  type        = string
  description = "Project ID hosting the central Backup and DR vault and backup plans."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region for the Backup and DR vault and plans."
}

variable "prefix" {
  type        = string
  description = "Naming prefix applied to the backup vault and plans."
}

variable "enforced_retention_days" {
  type        = number
  default     = 14
  description = "Minimum enforced backup retention in days (14 standard, 30 for regulated FSI)."

  validation {
    condition     = var.enforced_retention_days >= 1 && var.enforced_retention_days <= 3650
    error_message = "enforced_retention_days must be between 1 and 3650."
  }
}

variable "backup_retention_days" {
  type        = number
  default     = 30
  description = "Daily backup plan retention in days (clamped to at least enforced_retention_days)."

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 3650
    error_message = "backup_retention_days must be between 1 and 3650."
  }
}

variable "access_restriction" {
  type        = string
  default     = "WITHIN_ORGANIZATION"
  description = "Backup vault access boundary (WITHIN_PROJECT, WITHIN_ORGANIZATION, UNRESTRICTED, or WITHIN_ORG_BUT_UNRESTRICTED_FOR_BA)."

  validation {
    condition = contains([
      "WITHIN_PROJECT",
      "WITHIN_ORGANIZATION",
      "UNRESTRICTED",
      "WITHIN_ORG_BUT_UNRESTRICTED_FOR_BA",
    ], var.access_restriction)
    error_message = "access_restriction must be WITHIN_PROJECT, WITHIN_ORGANIZATION, UNRESTRICTED, or WITHIN_ORG_BUT_UNRESTRICTED_FOR_BA."
  }
}

variable "lock_backup_vault" {
  type        = bool
  default     = false
  description = "Whether to lock minimum retention effective_time on the backup vault."
}

variable "lock_effective_time" {
  type        = string
  default     = ""
  description = "RFC3339 timestamp when backup vault retention lock becomes immutable."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether to block force deletion of the backup vault."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional Cloud KMS key resource ID for backup vault encryption."
}

variable "enable_gce_backup_plan" {
  type        = bool
  default     = true
  description = "Whether to create a daily Backup and DR plan for Compute Engine instances."
}

variable "enable_cloudsql_backup_plan" {
  type        = bool
  default     = true
  description = "Whether to create a daily Backup and DR plan for Cloud SQL instances."
}

variable "backup_time_zone" {
  type        = string
  default     = "Asia/Kuala_Lumpur"
  description = "IANA time zone for daily backup schedule windows."
}

variable "authorized_backup_principals" {
  type        = list(string)
  default     = []
  description = "Optional IAM principals granted roles/backupdr.user on the backup project."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to Backup and DR vault and plan resources."
}
