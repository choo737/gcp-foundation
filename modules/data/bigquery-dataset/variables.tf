variable "project_id" {
  type        = string
  description = "GCP project ID for the BigQuery dataset."
}

variable "dataset_id" {
  type        = string
  description = "BigQuery dataset ID."
}

variable "region" {
  type        = string
  description = "BigQuery dataset location."
}

variable "friendly_name" {
  type        = string
  default     = null
  description = "Optional display name for the dataset."
}

variable "description" {
  type        = string
  default     = "Managed BigQuery dataset."
  description = "Dataset description."
}

variable "max_time_travel_hours" {
  type        = number
  default     = 168
  description = "Time travel retention window in hours (48 to 168)."

  validation {
    condition     = var.max_time_travel_hours >= 48 && var.max_time_travel_hours <= 168
    error_message = "max_time_travel_hours must be between 48 and 168."
  }
}

variable "default_partition_expiration_ms" {
  type        = number
  default     = null
  description = "Optional default expiration in milliseconds for partitioned tables."
}

variable "default_table_expiration_ms" {
  type        = number
  default     = null
  description = "Optional default expiration in milliseconds for tables in this dataset."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes tables inside the dataset."
}

variable "kms_key_name" {
  type        = string
  default     = null
  description = "Optional Cloud KMS key resource ID for default encryption."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the BigQuery dataset."
}

variable "readers" {
  type        = list(string)
  default     = []
  description = "IAM members granted roles/bigquery.dataViewer on the dataset."
}

variable "editors" {
  type        = list(string)
  default     = []
  description = "IAM members granted roles/bigquery.dataEditor on the dataset."
}
