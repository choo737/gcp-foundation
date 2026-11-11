variable "project_id" {
  type        = string
  description = "Sandbox GCP project ID where BigQuery, Dataplex, and Dataform run."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region for datasets, governance tags, scans, and Dataform."
}

variable "prefix" {
  type        = string
  default     = "bqfnd"
  description = "Name prefix applied to sandbox datasets, policies, and Dataform resources."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,14}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 3-16 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
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
  description = "Optional Secret Manager secret version for private Git authentication."
}

variable "kms_key_name" {
  type        = string
  default     = ""
  description = "Optional Cloud KMS key ID for BigQuery and Dataform encryption."
}

variable "masking_expression" {
  type        = string
  default     = "LAST_FOUR_CHARACTERS"
  description = "BigQuery predefined data masking expression attached to pii_masked."
}

variable "masked_readers" {
  type        = list(string)
  default     = []
  description = "IAM members granted masked reader access on Gold PII columns."
}

variable "fine_grained_readers" {
  type        = list(string)
  default     = []
  description = "IAM members granted unmasked fine-grained reader access."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops tables and dataset contents in the sandbox."
}

variable "enable_scheduled_workflow" {
  type        = bool
  default     = false
  description = "Whether to enable a daily Dataform workflow schedule in the sandbox."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation before creating dependent resources."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "sandbox"
    managed_by  = "terraform"
  }
  description = "Labels applied to sandbox resources."
}
