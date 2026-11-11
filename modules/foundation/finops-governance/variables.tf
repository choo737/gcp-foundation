variable "audit_project_id" {
  type        = string
  description = "Audit project ID hosting the FinOps billing export dataset, Pub/Sub topic, and tags."
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
  description = "BigQuery dataset location for billing export and job monitoring views."
}

variable "enable_billing_budget" {
  type        = bool
  default     = true
  description = "Whether to provision the monthly Cloud Billing budget."
}

variable "budget_project_numbers" {
  type        = list(string)
  default     = []
  description = "Optional list of numeric GCP project numbers scoped by the budget filter."
}

variable "monthly_budget_amount" {
  type        = number
  default     = 500
  description = "Monthly budget limit in whole currency units."

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

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops the billing export dataset contents and views."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to Pub/Sub, BigQuery dataset, and view resources."
}
