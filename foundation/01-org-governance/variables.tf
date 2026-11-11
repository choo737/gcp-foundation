variable "parent_id" {
  type        = string
  description = "Organization or parent folder ID formatted as organizations/<id> or folders/<id>."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID linked to foundation projects."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (2 to 8 lowercase chars) for folders and project IDs."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) for globally unique project and folder names."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region passed downstream."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether folders enforce deletion protection."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops FinOps BigQuery dataset contents and views."
}

variable "enable_org_policies" {
  type        = bool
  default     = false
  description = "Whether to enforce folder-level Org Policy guardrails."
}

variable "retention_days" {
  type        = number
  default     = 1095
  description = "Retention period in days for central audit logs (3-year baseline)."
}

variable "lock_audit_bucket" {
  type        = bool
  default     = false
  description = "Whether to lock the central Cloud Logging audit bucket."
}

variable "enable_data_access_audit_logs" {
  type        = bool
  default     = true
  description = "Whether to enable folder-level Data Access audit logs."
}

variable "enable_billing_budget" {
  type        = bool
  default     = true
  description = "Whether to create the foundation monthly Cloud Billing budget."
}

variable "budget_project_numbers" {
  type        = list(string)
  default     = []
  description = "Optional project numbers scoped by the monthly budget (empty covers the full billing account)."
}

variable "monthly_budget_amount" {
  type        = number
  default     = 500
  description = "Monthly FinOps budget threshold in whole currency units."
}

variable "budget_currency_code" {
  type        = string
  default     = "USD"
  description = "ISO-4217 currency code matching the billing account."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation on newly created projects."
}

variable "labels" {
  type = map(string)
  default = {
    layer      = "foundation"
    managed_by = "terraform"
  }
  description = "Labels applied to foundation projects and FinOps resources."
}
