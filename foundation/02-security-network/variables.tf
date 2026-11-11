variable "shared_infra_folder_id" {
  type        = string
  description = "Shared infrastructure folder ID from stage 01."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID for the network security project."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (2 to 8 lowercase chars) for project and security names."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) matching stage 01 for unique project IDs."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "GCP region for CMEK keys and optional subnets."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "enable_cmek" {
  type        = bool
  default     = true
  description = "Whether to create the regional KMS key ring and crypto key."
}

variable "kms_protection_level" {
  type        = string
  default     = "SOFTWARE"
  description = "Cloud KMS crypto key protection level (SOFTWARE or HSM)."
}

variable "enable_vpc" {
  type        = bool
  default     = false
  description = "Whether to create a shared VPC network and private subnet."
}

variable "enable_psc" {
  type        = bool
  default     = false
  description = "Whether to create a Private Service Connect endpoint for Google APIs."
}

variable "enable_vpc_sc" {
  type        = bool
  default     = false
  description = "Whether to create a VPC Service Controls perimeter."
}

variable "enforce_vpc_sc" {
  type        = bool
  default     = false
  description = "Whether to enforce the VPC-SC perimeter instead of dry-run mode."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation on the network security project."
}

variable "access_policy_id" {
  type        = string
  default     = ""
  description = "Access Context Manager policy ID for optional VPC-SC."
}

variable "perimeter_project_numbers" {
  type        = list(string)
  default     = []
  description = "Project numbers included inside the dry-run VPC-SC perimeter."
}

variable "labels" {
  type = map(string)
  default = {
    layer      = "foundation"
    managed_by = "terraform"
  }
  description = "Labels applied to security and network resources."
}
