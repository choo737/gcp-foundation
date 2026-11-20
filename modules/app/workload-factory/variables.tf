variable "applications" {
  type = map(object({
    display_name     = string
    enable_cloud_run = optional(bool, true)
    enable_gke       = optional(bool, false)
    enable_cloud_sql = optional(bool, false)
    admin_group      = optional(string, "")
    developer_group  = optional(string, "")
    env_groups       = optional(map(string), {})
  }))
  default     = {}
  description = "Declarative map of application workloads keyed by 2-6 character lowercase app_key."

  validation {
    condition = alltrue([
      for k, _ in var.applications :
      can(regex("^[a-z][a-z0-9-]{0,4}[a-z0-9]$", k))
    ])
    error_message = "Every applications map key must be 2-6 chars matching ^[a-z][a-z0-9-]{0,4}[a-z0-9]$."
  }
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (3 to 8 lowercase chars) for application project IDs."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 3-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) for globally unique project IDs."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (for example dev, uat, staging, prod)."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase alphanumeric or hyphens."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for subnet IAM bindings."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID attached to provisioned application projects."
}

variable "app_folder_id" {
  type        = string
  description = "Parent application department folder ID (folders/<id> or numeric)."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether per-application folders enforce deletion protection."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "shared_vpc_host_project_id" {
  type        = string
  default     = ""
  description = "Optional Shared VPC host project ID from foundation stage 02."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Optional app subnetwork resource ID from foundation stage 02."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID from foundation stage 02."
}

variable "manage_kms_iam" {
  type        = bool
  default     = true
  description = "Whether Terraform manages Cloud KMS IAM bindings on kms_key_id."
}

variable "shared_artifact_registry_id" {
  type        = string
  default     = ""
  description = "Optional shared golden Artifact Registry repository ID from stage 01."
}

variable "app_admins_group" {
  type        = string
  default     = ""
  description = "Optional platform-wide app admins Google Group email or member string."
}

variable "finops_tag_value_ids" {
  type        = map(string)
  default     = {}
  description = "Optional Resource Manager FinOps tag value IDs linked from stage 01."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after project API activation."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to provisioned application projects."
}
