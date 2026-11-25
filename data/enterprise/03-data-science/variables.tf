variable "enable_data_science" {
  type        = bool
  default     = true
  description = "Whether to provision optional Data Science and Regulated XAI stage resources."
}

variable "team_size_tier" {
  type        = string
  default     = "M"
  description = "Team sizing tier: S (co-located in data-etl), M, or L (isolated ds-exp and ml-ops projects)."

  validation {
    condition     = contains(["S", "M", "L"], var.team_size_tier)
    error_message = "team_size_tier must be S, M, or L."
  }
}

variable "compliance_profile" {
  type        = string
  default     = "enterprise_standard"
  description = "Compliance baseline (sandbox_poc, enterprise_standard, or regulated_fsi_rmit)."

  validation {
    condition     = contains(["sandbox_poc", "enterprise_standard", "regulated_fsi_rmit"], var.compliance_profile)
    error_message = "compliance_profile must be sandbox_poc, enterprise_standard, or regulated_fsi_rmit."
  }
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (dev, uat, or prod)."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase alphanumeric or hyphens."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region matching enterprise stage 01."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (3 to 8 lowercase chars) matching enterprise stage 01."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 3-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 4 chars) for globally unique project IDs."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,2}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-4 lowercase alphanumeric characters."
  }
}

variable "auto_unique_suffix" {
  type        = bool
  default     = true
  description = "When true and project_suffix is empty, appends a deterministic 4-hex code to project IDs."
}

variable "billing_account" {
  type        = string
  default     = ""
  description = "Cloud Billing account ID attached to ds-exp and ml-ops projects in tier M or L."
}

variable "compute_folder_id" {
  type        = string
  default     = ""
  description = "Compute subfolder ID fallback from stage 01."
}

variable "environment_compute_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Map of environment names to compute folder IDs from stage 01."
}

variable "ai_folder_id" {
  type        = string
  default     = ""
  description = "Optional AI department folder ID overriding compute_folder_id."
}

variable "environment_ai_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Map of environment names to ai folder IDs from stage 01."
}

variable "etl_compute_project_id" {
  type        = string
  default     = ""
  description = "ETL compute project ID from stage 01 (reused in team_size_tier S)."
}

variable "governance_project_id" {
  type        = string
  default     = ""
  description = "Governance project ID from stage 01 hosting pii_masked Data Policy."
}

variable "core_storage_project_id" {
  type        = string
  default     = ""
  description = "Core Bronze and Silver storage project ID from stage 01."
}

variable "silver_dataset_id" {
  type        = string
  default     = ""
  description = "Core Silver curated dataset ID from stage 01."
}

variable "primary_gold_project_id" {
  type        = string
  default     = ""
  description = "Primary Gold mart storage project ID from stage 01."
}

variable "primary_gold_dataset_id" {
  type        = string
  default     = ""
  description = "Primary Gold mart dataset ID from stage 01."
}

variable "pii_data_policy_short_id" {
  type        = string
  default     = ""
  description = "Short data_policy_id of the BigQuery PII masking policy from stage 01."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID from stage 02."
}

variable "manage_kms_iam" {
  type        = bool
  default     = true
  description = "Whether Terraform manages Cloud KMS IAM bindings on kms_key_id."
}

variable "shared_vpc_host_project_id" {
  type        = string
  default     = ""
  description = "Optional Shared VPC host project ID from stage 02."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "Optional VPC network resource ID from stage 02."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Optional private subnetwork resource ID from stage 02."
}

variable "enable_vertex_psc_policy" {
  type        = bool
  default     = true
  description = "Whether to provision a Network Connectivity Service Connection Policy for Agent Platform PSC automation when vpc_id and subnet_id are set."
}

variable "create_vertex_psc_policy" {
  type        = bool
  default     = null
  description = "Optional override controlling whether Stage 03 creates the Vertex PSC policy in network_project (defaults to false so Stage 02 owns network_project under per_stage WIF CI)."
}

variable "vertex_psc_service_connection_policy_id" {
  type        = string
  default     = ""
  description = "Optional upstream Vertex PSC Service Connection Policy ID linked from Stage 02."
}

variable "vpc_sc_perimeter_name" {
  type        = string
  default     = ""
  description = "Optional full VPC-SC service perimeter name from stage 02."
}

variable "enforce_vpc_sc" {
  type        = bool
  default     = false
  description = "Whether the VPC-SC perimeter is in enforced mode instead of dry-run mode."
}

variable "manage_vpc_sc" {
  type        = bool
  default     = true
  description = "Whether Terraform manages additive VPC-SC perimeter attachments and ingress policies."
}

variable "notification_channel_ids" {
  type        = list(string)
  default     = []
  description = "Cloud Monitoring notification channel resource names propagated from stage 02."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes BigQuery audit tables and non-locked bucket contents."
}

variable "finops_tag_value_ids" {
  type        = map(string)
  default     = {}
  description = "Optional Resource Manager FinOps tag value IDs linked from stage 01."
}

variable "shared_artifact_registry_id" {
  type        = string
  default     = ""
  description = "Optional shared golden Artifact Registry repository ID linked from stage 01."
}

variable "ds_analysts_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string for data science analysts."
}

variable "ai_admins_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string granted AI platform and monitoring viewer on ds-exp and ml-ops."
}

variable "env_groups" {
  type        = map(string)
  default     = {}
  description = "Optional map of environment names (dev, uat, prod) to collaborator Google Groups."
}

variable "enable_ds_workbench" {
  type        = bool
  default     = true
  description = "Whether to provision hardened Agent Platform Workbench instances in ds-exp."
}

variable "workbench_idle_timeout_seconds" {
  type        = number
  default     = 3600
  description = "Idle shutdown timeout in seconds for Workbench instances."
}

variable "workbench_instances" {
  type = map(object({
    zone              = optional(string, "")
    machine_type      = optional(string, "n2-standard-4")
    boot_disk_size_gb = optional(number, 150)
    data_disk_size_gb = optional(number, 100)
    owner_email       = optional(string, "")
    metadata          = optional(map(string), {})
  }))
  default     = {}
  description = "Map of hardened Agent Platform Workbench instances keyed by short suffix."
}

variable "enable_colab_enterprise" {
  type        = bool
  default     = false
  description = "Whether to create an optional Colab Enterprise runtime template (blocked in regulated_fsi_rmit)."
}

variable "colab_machine_type" {
  type        = string
  default     = "n1-standard-4"
  description = "Machine type for the optional Colab Enterprise runtime template."
}

variable "xai_audit_retention_days" {
  type        = number
  default     = 2555
  description = "Retention period in days for the WORM XAI audit archive bucket."
}

variable "shap_additivity_tolerance" {
  type        = number
  default     = 0.00001
  description = "Tolerance epsilon for SHAP logit additivity checks."
}

variable "enable_xai_quality_scan" {
  type        = bool
  default     = true
  description = "Whether to provision the Knowledge Catalog Auto data quality scan on ml_xai_audit_ledger."
}

variable "xai_quality_schedule_cron" {
  type        = string
  default     = ""
  description = "Optional cron schedule for the XAI audit Knowledge Catalog quality scan."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation and KMS IAM grants."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "enterprise"
    managed_by  = "terraform"
  }
  description = "Labels applied to Data Science and Regulated XAI resources."
}
