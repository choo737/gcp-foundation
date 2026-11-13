variable "scc_tier" {
  type        = string
  default     = "NONE"
  description = "Security Command Center tier to wire (NONE, STANDARD, or PREMIUM)."

  validation {
    condition     = contains(["NONE", "STANDARD", "PREMIUM"], var.scc_tier)
    error_message = "scc_tier must be NONE, STANDARD, or PREMIUM."
  }
}

variable "scc_location" {
  type        = string
  default     = "global"
  description = "SCC v2 API location (global, us, eu, or sa). BigQuery findings export still stores rows regionally in var.region."

  validation {
    condition     = contains(["global", "us", "eu", "sa"], var.scc_location)
    error_message = "scc_location must be global, us, eu, or sa."
  }
}

variable "folder_id" {
  type        = string
  description = "Root foundation folder ID (folders/<id> or numeric <id>)."
}

variable "environment_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Map of environment names to folder IDs (for example dev, staging, prod)."
}

variable "nonprod_mute_environments" {
  type        = set(string)
  default     = ["dev", "staging"]
  description = "Environment keys in environment_folder_ids that receive non-production SCC mute rules."
}

variable "nonprod_mute_filter" {
  type        = string
  default     = "category=\"SQL_WEAK_ROOT_PASSWORD\" OR category=\"BUCKET_LOGGING_DISABLED\" OR category=\"DATASET_CMEK_DISABLED\" OR category=\"VPC_FLOW_LOGS_SETTINGS_NOT_RECOMMENDED\""
  description = "SCC v2 mute filter applied to non-production environment folders."
}

variable "audit_project_id" {
  type        = string
  description = "Audit project ID hosting the SCC BigQuery dataset, Pub/Sub topic, and alerts."
}

variable "prefix" {
  type        = string
  description = "Naming prefix for SCC export, Pub/Sub, mute, and posture resources."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region where the SCC BigQuery findings dataset stores data."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional Cloud KMS key resource ID for SCC BigQuery dataset and Pub/Sub topic encryption."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops SCC BigQuery findings tables and data."
}

variable "alert_email_addresses" {
  type        = list(string)
  default     = []
  description = "Email addresses notified when unacknowledged HIGH or CRITICAL SCC findings arrive."
}

variable "enable_bigquery_export" {
  type        = bool
  default     = true
  description = "Whether STANDARD and PREMIUM tiers export active SCC findings to regional BigQuery."
}

variable "enable_pubsub_notifications" {
  type        = bool
  default     = true
  description = "Whether STANDARD and PREMIUM tiers stream HIGH and CRITICAL SCC findings to Pub/Sub and Cloud Monitoring."
}

variable "enable_nonprod_mute_rules" {
  type        = bool
  default     = true
  description = "Whether STANDARD and PREMIUM tiers create SCC mute rules on non-production folders."
}

variable "enable_custom_sha_modules" {
  type        = bool
  default     = true
  description = "Whether PREMIUM tier deploys Custom Security Health Analytics CEL modules."
}

variable "enable_security_posture" {
  type        = bool
  default     = false
  description = "Whether PREMIUM tier deploys a declarative Security Posture (requires organization_id)."
}

variable "organization_id" {
  type        = string
  default     = ""
  description = "Organization ID (organizations/<id> or <id>) required when enable_security_posture is true in PREMIUM."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to BigQuery, Pub/Sub, and Cloud Monitoring resources."
}
