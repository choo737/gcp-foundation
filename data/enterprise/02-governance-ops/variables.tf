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

variable "quarantine_dataset_id" {
  type        = string
  default     = ""
  description = "Optional quarantine dataset ID for Dataplex quality results export."
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

variable "dataform_custom_role_ids" {
  type        = map(string)
  default     = {}
  description = "Optional map of project IDs to custom dataform_pipeline_runner role IDs from stage 01."
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

variable "vpc_sc_perimeter_name" {
  type        = string
  default     = ""
  description = "Optional full VPC-SC service perimeter name for Dataform runtime ingress."
}

variable "enforce_vpc_sc" {
  type        = bool
  default     = false
  description = "Whether the VPC-SC perimeter is in enforced mode instead of dry-run mode."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (for example dev, staging, prod)."
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
  description = "Git branch, tag, or commit SHA compiled by the Dataform release config."
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
  default     = false
  description = "Whether to enable a standalone Dataform workflow schedule (false when Cloud Workflows triggers runs)."
}

variable "enable_quality_scan" {
  type        = bool
  default     = true
  description = "Whether to provision the Dataplex data quality scan on silver.fct_orders."
}

variable "quality_target_table_id" {
  type        = string
  default     = "fct_orders"
  description = "BigQuery table ID in silver_curated targeted by the Dataplex data quality scan."
}

variable "quality_results_table" {
  type        = string
  default     = ""
  description = "Optional full BigQuery resource URI for Dataplex quality results export."
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

variable "dataplex_iam_propagation_seconds" {
  type        = string
  default     = "90s"
  description = "Wait duration after Dataplex maskedReader IAM binding before creating data scans."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "enterprise"
    managed_by  = "terraform"
  }
  description = "Labels applied to Dataform, Dataplex, and seeded BigQuery tables."
}
