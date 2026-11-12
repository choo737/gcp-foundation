variable "project_id" {
  type        = string
  description = "Security and network project ID hosting KMS and VPC resources."
}

variable "region" {
  type        = string
  description = "GCP region for KMS key rings and optional subnetworks."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to KMS, VPC, and perimeter resources."
}

variable "enable_cmek" {
  type        = bool
  default     = true
  description = "Whether to provision a regional KMS key ring and crypto key."
}

variable "kms_protection_level" {
  type        = string
  default     = "SOFTWARE"
  description = "Cloud KMS crypto key protection level (SOFTWARE or HSM)."

  validation {
    condition     = contains(["SOFTWARE", "HSM"], var.kms_protection_level)
    error_message = "kms_protection_level must be SOFTWARE or HSM."
  }
}

variable "enable_vpc" {
  type        = bool
  default     = false
  description = "Whether to provision a custom VPC network and private subnet."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.20.0.0/20"
  description = "Primary CIDR range for the optional subnetwork."
}

variable "enable_vpc_flow_logs" {
  type        = bool
  default     = true
  description = "Whether to enable VPC Flow Logs on the private subnetwork."
}

variable "vpc_flow_logs_sampling" {
  type        = number
  default     = 0.5
  description = "Sampling rate (0.0 to 1.0) for VPC Flow Logs on the private subnetwork."

  validation {
    condition     = var.vpc_flow_logs_sampling >= 0 && var.vpc_flow_logs_sampling <= 1
    error_message = "vpc_flow_logs_sampling must be between 0.0 and 1.0."
  }
}

variable "enable_dns_logging" {
  type        = bool
  default     = true
  description = "Whether to enable Cloud DNS query logging on the custom VPC."
}

variable "enable_psc" {
  type        = bool
  default     = false
  description = "Whether to provision a Private Service Connect endpoint and private DNS zone."
}

variable "psc_ip_address" {
  type        = string
  default     = "10.250.0.10"
  description = "Internal IP address reserved for Private Service Connect."
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

variable "access_policy_id" {
  type        = string
  default     = ""
  description = "Organization Access Context Manager policy ID for VPC-SC."
}

variable "perimeter_project_numbers" {
  type        = list(string)
  default     = []
  description = "Project numbers included in the VPC-SC perimeter."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to KMS and Private Service Connect resources."
}
