variable "data_folder_id" {
  type        = string
  description = "Parent data platform folder ID (numeric or folders/<id>)."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID attached to enterprise data projects."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (2 to 8 lowercase chars) for enterprise projects and datasets."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) for globally unique project IDs."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for storage, governance, and BigQuery compute."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID from foundation stage 02."
}

variable "domain_marts" {
  type        = set(string)
  default     = ["fin"]
  description = "Short domain codes for dedicated Gold mart storage projects."

  validation {
    condition     = length(var.domain_marts) >= 1 && alltrue([for d in var.domain_marts : can(regex("^[a-z0-9]{2,6}$", d))])
    error_message = "domain_marts must have at least one 2-6 character lowercase alphanumeric code."
  }
}

variable "primary_domain" {
  type        = string
  default     = "fin"
  description = "Primary domain code in var.domain_marts used for primary Gold outputs."
}

variable "masking_expression" {
  type        = string
  default     = "LAST_FOUR_CHARACTERS"
  description = "BigQuery predefined data masking expression attached to pii_masked."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether storage and compute folders enforce deletion protection."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes tables and landing objects."
}

variable "enable_reservations" {
  type        = bool
  default     = true
  description = "Whether to provision BigQuery Enterprise slot reservations."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after project API activation and KMS IAM grants."
}

variable "masked_readers" {
  type        = list(string)
  default     = []
  description = "IAM members granted masked reader access on Gold PII columns."
}

variable "fine_grained_readers" {
  type        = list(string)
  default     = []
  description = "IAM members granted unmasked fine-grained reader access."
}

variable "bi_analysts" {
  type        = list(string)
  default     = []
  description = "BI analyst principals granted Gold viewer access, jobUser on data-bi, and masked reads."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "enterprise"
    managed_by  = "terraform"
  }
  description = "Labels applied to enterprise data platform resources."
}
