variable "project_id" {
  type        = string
  description = "GCP project ID hosting the Dataform repository."
}

variable "region" {
  type        = string
  description = "GCP region for the Dataform repository and compilation."
}

variable "prefix" {
  type        = string
  description = "Name prefix used when creating the default ETL service account."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name used for default Dataform release and workflow config names."
}

variable "repository_name" {
  type        = string
  description = "Dataform repository ID."
}

variable "release_config_name" {
  type        = string
  default     = null
  description = "Optional release configuration name, defaulting to <environment>-main."
}

variable "workflow_config_name" {
  type        = string
  default     = null
  description = "Optional workflow configuration name, defaulting to <environment>-daily."
}

variable "display_name" {
  type        = string
  default     = null
  description = "Optional display name for the Dataform repository."
}

variable "service_account_email" {
  type        = string
  default     = ""
  description = "Optional existing service account email for Dataform execution."
}

variable "deletion_policy" {
  type        = string
  default     = "FORCE"
  description = "Deletion policy for the Dataform repository."
}

variable "git_remote_url" {
  type        = string
  default     = ""
  description = "HTTPS Git remote URL for the Dataform repository."
}

variable "git_default_branch" {
  type        = string
  default     = "main"
  description = "Default Git branch tracked by the Dataform repository."
}

variable "git_release_commitish" {
  type        = string
  default     = "main"
  description = "Git branch, tag, or commit SHA compiled by the release config."
}

variable "kms_key_name" {
  type        = string
  default     = ""
  description = "Optional Cloud KMS key resource ID for Dataform repository encryption."
}

variable "git_token_secret_version" {
  type        = string
  default     = ""
  description = "Secret Manager secret version enabling Git remote linking (empty deploys standalone)."

  validation {
    condition     = var.git_token_secret_version == "" || can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.git_token_secret_version))
    error_message = "git_token_secret_version must be empty or projects/<project>/secrets/<secret>/versions/<version>."
  }
}

variable "default_database" {
  type        = string
  default     = ""
  description = "Default BigQuery project ID passed to Dataform compilation."
}

variable "bronze_project" {
  type        = string
  default     = ""
  description = "Project ID passed as the bronze_project compilation variable."
}

variable "bronze_dataset" {
  type        = string
  description = "Dataset ID passed as the bronze_dataset compilation variable."
}

variable "silver_project" {
  type        = string
  default     = ""
  description = "Project ID passed as the silver_project compilation variable."
}

variable "silver_dataset" {
  type        = string
  description = "Dataset ID passed as default_schema and silver_dataset."
}

variable "gold_project" {
  type        = string
  default     = ""
  description = "Project ID passed as the gold_project compilation variable."
}

variable "gold_dataset" {
  type        = string
  description = "Dataset ID passed as the gold_dataset compilation variable."
}

variable "assertion_schema" {
  type        = string
  description = "Dataset ID used by Dataform to write assertion tables."
}

variable "pii_policy_tag" {
  type        = string
  description = "Data Catalog policy tag ID passed as pii_policy_tag."
}

variable "pii_masked_policy_tag" {
  type        = string
  default     = ""
  description = "Data Catalog masked PII policy tag ID passed as pii_masked_policy_tag."
}

variable "pii_restricted_policy_tag" {
  type        = string
  default     = ""
  description = "Data Catalog restricted PII policy tag ID passed as pii_restricted_policy_tag."
}

variable "release_cron_schedule" {
  type        = string
  default     = null
  description = "Optional cron schedule for automatic release compilation (defaults to 45 1 * * * when scheduled workflow is enabled)."
}

variable "enable_scheduled_workflow" {
  type        = bool
  default     = false
  description = "Whether to create a scheduled Dataform workflow config."
}

variable "workflow_cron_schedule" {
  type        = string
  default     = "0 2 * * *"
  description = "Cron schedule used when enable_scheduled_workflow is true."
}

variable "extra_compilation_vars" {
  type        = map(string)
  default     = {}
  description = "Additional compilation variables passed to Dataform."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the Dataform repository."
}
