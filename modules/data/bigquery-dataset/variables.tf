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
