variable "shared_infra_folder_id" {
  type        = string
  default     = ""
  description = "Shared infrastructure folder ID from stage 01."
}

variable "folder_id" {
  type        = string
  default     = ""
  description = "Optional explicit target folder ID overriding shared_infra_folder_id."
}

variable "environment_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Optional map of environment names to 02-environments/<env> folder IDs from stage 01."
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Target lifecycle environment name (for example dev, staging, prod)."

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment))
    error_message = "environment must be lowercase alphanumeric or hyphens."
  }
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

variable "dr_region" {
  type        = string
  default     = null
  description = "Optional disaster recovery GCP region for a secondary CMEK key."
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

variable "enable_shared_vpc_host" {
  type        = bool
  default     = false
  description = "Whether to enable Shared VPC host mode on the network project."
}

variable "subnet_cidr" {
  type        = string
  default     = "10.20.0.0/20"
  description = "Primary CIDR range for the optional private subnetwork."
}

variable "enable_datastream_psc_attachment" {
  type        = bool
  default     = false
  description = "Whether to create a Datastream PSC NAT subnet and Network Attachment."
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
  description = "Sampling rate (0.0 to 1.0) for VPC Flow Logs."
}

variable "enable_dns_logging" {
  type        = bool
  default     = true
  description = "Whether to enable Cloud DNS query logging on the custom VPC."
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

variable "vpc_sc_ingress_principals" {
  type        = list(string)
  default     = []
  description = "IAM principals (for example WIF CI SAs or break-glass admins) allowed VPC-SC ingress."
}

variable "vpc_sc_audit_project_number" {
  type        = string
  default     = ""
  description = "Explicit audit project number allowed VPC-SC egress for logging and BigQuery."
}

variable "audit_project_number" {
  type        = string
  default     = ""
  description = "Linked audit project number from stage 01 used as VPC-SC audit egress fallback."
}

variable "vpc_sc_access_level_members" {
  type        = list(string)
  default     = []
  description = "Optional IAM members for an ACM access level attached to the VPC-SC perimeter."
}

variable "enable_alerts" {
  type        = bool
  default     = true
  description = "Whether to provision Cloud Monitoring notification channels and alert policies."
}

variable "alert_email_addresses" {
  type        = list(string)
  default     = []
  description = "Email addresses notified by Cloud Monitoring alert policies."
}

variable "alert_pubsub_topic_id" {
  type        = string
  default     = ""
  description = "Optional Pub/Sub topic resource ID for Cloud Monitoring alerts."
}

variable "dlq_backlog_threshold" {
  type        = number
  default     = 0
  description = "Maximum undelivered Pub/Sub DLQ messages before firing an alert."
}

variable "bigquery_slot_threshold" {
  type        = number
  default     = 100
  description = "BigQuery allocated slot threshold before firing a saturation alert."
}

variable "finops_tag_value_ids" {
  type        = map(string)
  default     = {}
  description = "Optional Resource Manager FinOps tag value IDs linked from stage 01."
}

variable "labels" {
  type = map(string)
  default = {
    layer      = "foundation"
    managed_by = "terraform"
  }
  description = "Labels applied to security and network resources."
}
