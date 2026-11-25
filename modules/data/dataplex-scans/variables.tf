variable "project_id" {
  type        = string
  description = "GCP project ID hosting Knowledge Catalog data profile and quality scans."
}

variable "region" {
  type        = string
  description = "GCP region for Knowledge Catalog data scans."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to Knowledge Catalog scan IDs."
}

variable "profile_tables" {
  type = map(object({
    project_id       = string
    dataset_id       = string
    table_id         = string
    sampling_percent = optional(number, 100)
    display_name     = optional(string, null)
    description      = optional(string, "On-demand Knowledge Catalog data profile scan.")
  }))
  default     = {}
  description = "Map of BigQuery tables to attach on-demand Knowledge Catalog data profile scans."
}

variable "enable_quality_scan" {
  type        = bool
  default     = true
  description = "Whether to provision the Knowledge Catalog data quality scan on Silver orders."
}

variable "quality_target_project_id" {
  type        = string
  default     = ""
  description = "BigQuery project ID hosting the target table for the data quality scan."
}

variable "quality_target_dataset_id" {
  type        = string
  default     = ""
  description = "BigQuery dataset ID hosting the target table for the data quality scan."
}

variable "quality_target_table_id" {
  type        = string
  default     = "fct_orders"
  description = "BigQuery table ID evaluated by the Knowledge Catalog data quality scan."
}

variable "quality_sampling_percent" {
  type        = number
  default     = 100
  description = "Sampling percentage (0 to 100) for the Knowledge Catalog data quality scan."
}

variable "quarantine_dataset_id" {
  type        = string
  default     = ""
  description = "Optional quarantine dataset ID used to export quality results when quality_results_table is empty."
}

variable "quality_results_table" {
  type        = string
  default     = ""
  description = "Optional BigQuery resource URI (//bigquery.googleapis.com/projects/.../tables/...) for quality results export."
}

variable "quarantine_project_id" {
  type        = string
  default     = ""
  description = "Optional GCP project ID hosting quarantine_dataset_id (defaults to quality target project)."
}

variable "quality_scan_id" {
  type        = string
  default     = ""
  description = "Optional custom Knowledge Catalog data quality scan ID overriding the default scan identifier."
}

variable "quality_row_filter" {
  type        = string
  default     = ""
  description = "Optional BigQuery SQL WHERE filter applied to quality scans (overrides default lookback window)."
}

variable "quality_lookback_days" {
  type        = number
  default     = 7
  description = "Rolling partition-pruned lookback window in days for the default Silver orders quality scan."

  validation {
    condition     = var.quality_lookback_days >= 1
    error_message = "quality_lookback_days must be at least 1."
  }
}

variable "quality_schedule_cron" {
  type        = string
  default     = ""
  description = "Optional cron schedule for periodic quality scans (empty uses on-demand execution)."
}

variable "quality_rules" {
  type = list(object({
    name          = string
    dimension     = string
    column        = optional(string, "")
    threshold     = optional(number, 1.0)
    non_null      = optional(bool, false)
    sql_assertion = optional(string, "")
    min_value     = optional(string, "")
    max_value     = optional(string, "")
    set_values    = optional(list(string), [])
    regex_pattern = optional(string, "")
  }))
  default     = []
  description = "Optional declarative quality rules evaluated instead of the default Silver orders rules."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to Knowledge Catalog scan resources."
}
