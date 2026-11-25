variable "audit_project_id" {
  type        = string
  description = "Audit project ID used as fallback when finops_project_id is empty."
}

variable "finops_project_id" {
  type        = string
  default     = ""
  description = "Dedicated FinOps project ID hosting billing export, budgets, and alerts."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID monitored by the monthly budget."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to FinOps topics, budgets, and datasets."
}

variable "region" {
  type        = string
  description = "Default GCP region for FinOps metadata and regional queries."
}

variable "billing_export_location" {
  type        = string
  default     = "US"
  description = "BigQuery dataset location for Cloud Billing export (US recommended for 2-month backfill; EU or regional also supported)."
}

variable "enable_billing_budget" {
  type        = bool
  default     = true
  description = "Whether to provision Cloud Billing budgets and notification channels."
}

variable "budget_project_numbers" {
  type        = list(string)
  default     = []
  description = "Optional list of numeric GCP project numbers scoped by the master budget filter."
}

variable "monthly_budget_amount" {
  type        = number
  default     = 500
  description = "Master monthly budget limit in whole currency units."

  validation {
    condition     = var.monthly_budget_amount > 0
    error_message = "monthly_budget_amount must be greater than zero."
  }
}

variable "budget_currency_code" {
  type        = string
  default     = "USD"
  description = "ISO-4217 currency code matching the billing account currency."
}

variable "alert_email_addresses" {
  type        = list(string)
  default     = []
  description = "Up to 5 FinOps group email addresses notified via Cloud Monitoring channels."
}

variable "environment_budgets" {
  type        = map(number)
  default     = {}
  description = "Optional map of environment names to monthly budget amounts scoped to environment folders."

  validation {
    condition     = alltrue([for v in values(var.environment_budgets) : v > 0])
    error_message = "All environment_budgets amounts must be greater than zero."
  }
}

variable "environment_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Map of environment names to folder IDs used to scope per-environment budgets."
}

variable "workload_budgets" {
  type = map(object({
    amount       = number
    projects     = optional(list(string), [])
    labels       = optional(map(string), {})
    alert_emails = optional(list(string), [])
  }))
  default     = {}
  description = "Optional map of workload budgets scoped by project numbers or labels."

  validation {
    condition     = alltrue([for w in values(var.workload_budgets) : w.amount > 0])
    error_message = "All workload_budgets amounts must be greater than zero."
  }

  validation {
    condition     = alltrue([for w in values(var.workload_budgets) : (length(w.projects) > 0 || length(w.labels) > 0) && length(w.labels) <= 1])
    error_message = "Each workload_budgets entry requires projects or at most 1 resource-level label key (Cloud Billing budgets ignore RM tags and project labels)."
  }
}

variable "department_budgets" {
  type        = map(number)
  default     = {}
  description = "Optional map of department cost_center keys (platform, shared, data, ai, app, security, network) to monthly budget amounts."

  validation {
    condition = alltrue([
      for k, v in var.department_budgets :
      contains(["platform", "shared", "data", "ai", "app", "security", "network"], k) && v > 0
    ])
    error_message = "department_budgets keys must be in [platform, shared, data, ai, app, security, network] and amounts must be greater than zero."
  }
}

variable "department_budget_ancestors" {
  type        = map(list(string))
  default     = {}
  description = "Optional map of cost_center keys to folder/organization ancestors or project numbers (folders/<id>, organizations/<id>, or projects/<number>) scoping department budgets."

  validation {
    condition = alltrue([
      for k, items in var.department_budget_ancestors :
      alltrue([for item in items : startswith(item, "projects/") || startswith(item, "folders/") || startswith(item, "organizations/")]) &&
      !(anytrue([for item in items : startswith(item, "projects/")]) && anytrue([for item in items : startswith(item, "folders/") || startswith(item, "organizations/")]))
    ])
    error_message = "Every department_budget_ancestors entry must start with projects/, folders/, or organizations/, and cannot mix projects/ with folders/ or organizations/ under the same key."
  }
}

variable "billing_export_table_name" {
  type        = string
  default     = ""
  description = "Optional Cloud Billing BigQuery export table name enabling v_finops_department_spend."
}

variable "finops_admins_group" {
  type        = string
  default     = ""
  description = "Optional FinOps admin Google Group granted billing costsManager and FinOps BigQuery access."
}

variable "budget_thresholds" {
  type        = list(number)
  default     = [0.5, 0.8, 0.9, 1.0]
  description = "Current-spend alert threshold percentages for Cloud Billing budgets."

  validation {
    condition     = length(var.budget_thresholds) > 0 && alltrue([for t in var.budget_thresholds : t > 0])
    error_message = "budget_thresholds must be non-empty positive numbers."
  }
}

variable "enable_forecasted_threshold" {
  type        = bool
  default     = true
  description = "Whether budgets include a 100% forecasted-spend alert threshold."
}

variable "disable_default_iam_recipients" {
  type        = bool
  default     = false
  description = "Whether to suppress default billing IAM email recipients and route solely via Monitoring and Pub/Sub."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops the billing export dataset contents and views."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to Pub/Sub, BigQuery dataset, monitoring channels, and view resources."
}
