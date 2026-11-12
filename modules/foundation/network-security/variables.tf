variable "project_id" {
  type        = string
  description = "Security and network project ID hosting KMS and VPC resources."
}

variable "network_project_number" {
  type        = string
  default     = ""
  description = "Optional numeric project number for the network project added to the VPC-SC perimeter."
}

variable "region" {
  type        = string
  description = "GCP region for KMS key rings and optional subnetworks."
}

variable "dr_region" {
  type        = string
  default     = null
  description = "Optional disaster recovery GCP region for a secondary CMEK key."
}

variable "prefix" {
  type        = string
  description = "Name prefix applied to KMS, VPC, and perimeter resources."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (for example dev, staging, prod)."
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

variable "enable_shared_vpc_host" {
  type        = bool
  default     = false
  description = "Whether to register this network project as a Shared VPC host."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.20.0.0/20"
  description = "Primary CIDR range for the optional subnetwork."
}

variable "enable_datastream_psc_attachment" {
  type        = bool
  default     = false
  description = "Whether to provision a PSC NAT subnet and Network Attachment for Datastream."
}

variable "datastream_nat_subnet_cidr" {
  type        = string
  default     = "10.20.16.0/24"
  description = "CIDR range for the Datastream PSC network attachment subnet."
}

variable "datastream_producer_accept_lists" {
  type        = list(string)
  default     = []
  description = "Optional producer project IDs allowed to connect to the Datastream Network Attachment."
}

variable "allowed_private_db_cidrs" {
  type        = list(string)
  default     = []
  description = "Optional private DB CIDRs allowed egress on TCP 5432 and 3306."
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

variable "vpc_sc_ingress_principals" {
  type        = list(string)
  default     = []
  description = "IAM principals (for example CI WIF SAs or break-glass admins) allowed VPC-SC ingress."
}

variable "vpc_sc_audit_project_number" {
  type        = string
  default     = ""
  description = "Optional audit project number allowed VPC-SC egress for logging and BigQuery."
}

variable "vpc_sc_access_level_members" {
  type        = list(string)
  default     = []
  description = "Optional IAM members for an ACM access level attached to the VPC-SC perimeter."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to KMS and Private Service Connect resources."
}
