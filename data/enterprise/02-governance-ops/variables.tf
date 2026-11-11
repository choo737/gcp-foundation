variable "governance_project_id" {
  type        = string
  description = "Governance project ID from enterprise stage 01."
}

variable "core_storage_project_id" {
  type        = string
  description = "Core Bronze and Silver storage project ID from stage 01."
}

variable "primary_gold_project_id" {
  type        = string
  description = "Primary Gold mart storage project ID from stage 01."
}

variable "domain_storage_project_ids" {
  type        = map(string)
  default     = {}
  description = "Map of domain codes to Gold mart storage project IDs from stage 01."
}

variable "etl_compute_project_id" {
  type        = string
  description = "ETL compute project ID hosting Dataform from stage 01."
}

variable "bronze_dataset_id" {
  type        = string
  description = "Core Bronze dataset ID."
}

variable "silver_dataset_id" {
  type        = string
  description = "Core Silver curated dataset ID."
}

variable "assertions_dataset_id" {
  type        = string
  description = "Core Silver assertions dataset ID."
}

variable "primary_gold_dataset_id" {
  type        = string
  description = "Primary Gold mart dataset ID."
}

variable "domain_gold_dataset_ids" {
  type        = map(string)
  default     = {}
  description = "Map of domain codes to Gold mart dataset IDs from stage 01."
}

variable "pii_masked_policy_tag_id" {
  type        = string
  description = "Masked PII policy tag resource name from data-gov."
}

variable "pii_restricted_policy_tag_id" {
  type        = string
  description = "Restricted PII policy tag resource name from data-gov."
}

variable "pii_data_policy_short_id" {
  type        = string
  default     = ""
  description = "Short data_policy_id of the BigQuery PII masking policy from data-gov."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID from stage 01."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region matching enterprise stage 01."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Naming prefix matching enterprise stage 01."
}

variable "medallion_git_url" {
  type        = string
  default     = "https://github.com/choo737/gcp-data-medallion.git"
  description = "Public Git remote URL for the Medallion Dataform repository."
}

variable "medallion_git_branch" {
  type        = string
  default     = "main"
  description = "Git branch tracked by the Dataform repository."
}

variable "git_release_commitish" {
  type        = string
  default     = "main"
  description = "Git branch, tag, or commit SHA compiled by the prod-main release config."
}

variable "git_token_secret_version" {
  type        = string
  default     = ""
  description = "Secret Manager secret version for Dataform Git sync (empty uses standalone mode)."

  validation {
    condition     = var.git_token_secret_version == "" || can(regex("^projects/[^/]+/secrets/[^/]+/versions/[^/]+$", var.git_token_secret_version))
    error_message = "git_token_secret_version must be empty or projects/<project>/secrets/<secret>/versions/<version>."
  }
}

variable "enable_scheduled_workflow" {
  type        = bool
  default     = true
  description = "Whether to enable a daily scheduled Dataform workflow run."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes seeded tables, ops telemetry dataset, and views."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after service agent and KMS IAM grants."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "enterprise"
    managed_by  = "terraform"
  }
  description = "Labels applied to Dataform, Dataplex, and seeded BigQuery tables."
}
