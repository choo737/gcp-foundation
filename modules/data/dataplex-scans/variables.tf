variable "project_id" {
  type        = string
  description = "GCP project ID hosting Dataplex data profile scans."
}

variable "region" {
  type        = string
  description = "GCP region for Dataplex data scans."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to Dataplex scan IDs."
}

variable "profile_tables" {
  type = map(object({
    project_id       = string
    dataset_id       = string
    table_id         = string
    sampling_percent = optional(number, 100)
    display_name     = optional(string, null)
    description      = optional(string, "On-demand Dataplex data profile scan.")
  }))
  default     = {}
  description = "Map of BigQuery tables to attach on-demand Dataplex data profile scans."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to Dataplex scan resources."
}
