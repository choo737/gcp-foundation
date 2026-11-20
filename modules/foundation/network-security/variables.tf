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

variable "allowed_cmek_service_agents" {
  type        = list(string)
  default     = []
  description = "Optional upstream service agents or service accounts granted Cloud KMS EncrypterDecrypter on primary and DR CMEK keys."
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

variable "department_subnet_cidrs" {
  type        = map(string)
  default     = {}
  description = "Optional isolated department subnet CIDRs keyed by data, ai, or app."

  validation {
    condition = alltrue([
      for k, v in var.department_subnet_cidrs :
      contains(["data", "ai", "app"], k) &&
      can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/([0-9]|[1-2][0-9]|3[0-2])$", v)) &&
      can(cidrhost(v, 0))
    ])
    error_message = "department_subnet_cidrs keys must be in [data, ai, app] and values must be valid IPv4 CIDRs."
  }
}

variable "department_subnet_secondary_ranges" {
  type = map(object({
    pods_cidr     = string
    services_cidr = string
  }))
  default     = {}
  description = "Optional GKE secondary IP ranges (pods_cidr and services_cidr) keyed by data, ai, or app."

  validation {
    condition = alltrue([
      for k, v in var.department_subnet_secondary_ranges :
      contains(["data", "ai", "app"], k) &&
      can(cidrhost(v.pods_cidr, 0)) &&
      can(cidrhost(v.services_cidr, 0))
    ])
    error_message = "department_subnet_secondary_ranges keys must be in [data, ai, app] with valid pods_cidr and services_cidr."
  }
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

variable "vpc_sc_secops_project_number" {
  type        = string
  default     = ""
  description = "Optional SecOps project number allowed VPC-SC egress for shared Artifact Registry pulls."
}

variable "vpc_sc_access_level_members" {
  type        = list(string)
  default     = []
  description = "Optional IAM members for an ACM access level attached to the VPC-SC perimeter."
}

variable "enable_hierarchical_firewall_policy" {
  type        = bool
  default     = false
  description = "Whether to create and associate a folder-level hierarchical firewall policy."
}

variable "firewall_policy_folder_id" {
  type        = string
  default     = ""
  description = "Folder resource ID (folders/<id> or numeric) attached to the hierarchical firewall policy."
}

variable "enable_ngfw_standard_rules" {
  type        = bool
  default     = true
  description = "Whether to enable NGFW Standard threat intelligence deny rules on folder and VPC policies."
}

variable "threat_intelligence_lists" {
  type        = list(string)
  default     = ["iplist-known-malicious-ips", "iplist-tor-exit-nodes", "iplist-crypto-miners"]
  description = "Google threat intelligence feed names blocked at ingress and egress."
}

variable "enable_iap_ssh_ingress" {
  type        = bool
  default     = true
  description = "Whether to permit IAP TCP forwarding (35.235.240.0/20 on ports 22 and 3389)."
}

variable "enable_secure_tags" {
  type        = bool
  default     = true
  description = "Whether to create IAM-governed GCE_FIREWALL secure tags for NGFW policies."
}

variable "allowed_egress_fqdns" {
  type        = list(string)
  default     = []
  description = "Optional list of external FQDNs permitted on HTTPS egress in the VPC firewall policy."
}

variable "enable_ngfw_enterprise" {
  type        = bool
  default     = false
  description = "Whether to opt into NGFW Enterprise zonal firewall endpoints and threat prevention profiles."
}

variable "organization_id" {
  type        = string
  default     = ""
  description = "Organization ID (organizations/<id> or <id>) required when enable_ngfw_enterprise is true."
}

variable "ngfw_enterprise_zones" {
  type        = list(string)
  default     = []
  description = "Zones for NGFW Enterprise firewall endpoints (defaults to <region>-a and <region>-b)."
}

variable "enable_ngfw_tls_inspection" {
  type        = bool
  default     = false
  description = "Whether NGFW Enterprise rules inspect TLS traffic using ngfw_tls_inspection_policy_id."
}

variable "ngfw_tls_inspection_policy_id" {
  type        = string
  default     = ""
  description = "Optional TLS inspection policy resource ID bound to NGFW Enterprise endpoint associations."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to KMS and Private Service Connect resources."
}
