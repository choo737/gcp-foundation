variable "ds_exp_project_id" {
  type        = string
  description = "Data science experimentation project ID hosting Workbench and Colab templates."
}

variable "ml_ops_project_id" {
  type        = string
  description = "MLOps project ID hosting ML containers, Metadata Store, XAI audit ledger, and WORM bucket."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for ML governance resources."
}

variable "prefix" {
  type        = string
  description = "Short naming prefix for repositories, datasets, and Dataplex scans."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (dev, staging, or prod)."
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

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID."
}

variable "manage_kms_iam" {
  type        = bool
  default     = true
  description = "Whether Terraform manages Cloud KMS IAM bindings on kms_key_id."
}

variable "enable_vertex_psc_policy" {
  type        = bool
  default     = true
  description = "Whether to provision a Network Connectivity Service Connection Policy for Vertex AI PSC automation when vpc_id and subnet_id are set."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "Optional VPC network resource ID for private Workbench and Colab networking."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Optional private subnetwork resource ID for Workbench and Colab networking."
}

variable "enable_ds_workbench" {
  type        = bool
  default     = true
  description = "Whether to provision hardened Vertex AI Workbench instances."
}

variable "workbench_runtime_sa_email" {
  type        = string
  default     = ""
  description = "Custom service account email attached to Workbench VM instances."
}

variable "workbench_idle_timeout_seconds" {
  type        = number
  default     = 3600
  description = "Idle auto-shutdown timeout in seconds for Workbench instances."

  validation {
    condition     = var.workbench_idle_timeout_seconds >= 600 && var.workbench_idle_timeout_seconds <= 86400
    error_message = "workbench_idle_timeout_seconds must be between 600 and 86400."
  }
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
  description = "Map of hardened Vertex AI Workbench instances keyed by short suffix."
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
  description = "Retention period in days for the WORM XAI audit archive bucket (default 7 years)."

  validation {
    condition     = var.xai_audit_retention_days >= 1
    error_message = "xai_audit_retention_days must be at least 1."
  }
}

variable "shap_additivity_tolerance" {
  type        = number
  default     = 0.00001
  description = "Tolerance epsilon for SHAP logit additivity Dataplex validation."

  validation {
    condition     = var.shap_additivity_tolerance > 0 && var.shap_additivity_tolerance <= 0.01
    error_message = "shap_additivity_tolerance must be greater than 0 and at most 0.01."
  }
}

variable "enable_xai_quality_scan" {
  type        = bool
  default     = true
  description = "Whether to provision the Dataplex AutoDQ scan on ml_xai_audit_ledger."
}

variable "xai_quality_schedule_cron" {
  type        = string
  default     = ""
  description = "Optional cron schedule for the XAI audit Dataplex quality scan."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes dataset tables and non-locked bucket contents."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to ML governance resources."
}
