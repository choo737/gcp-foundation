variable "data_folder_id" {
  type        = string
  default     = ""
  description = "Parent data platform folder ID for brownfield fallback (numeric or folders/<id>)."
}

variable "storage_folder_id" {
  type        = string
  default     = ""
  description = "Optional existing storage subfolder ID overriding subfolder creation."
}

variable "compute_folder_id" {
  type        = string
  default     = ""
  description = "Optional existing compute subfolder ID overriding subfolder creation."
}

variable "environment_storage_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Optional map of environment names to storage folder IDs from stage 01."
}

variable "environment_compute_folder_ids" {
  type        = map(string)
  default     = {}
  description = "Optional map of environment names to compute folder IDs from stage 01."
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
  description = "Cloud Billing account ID attached to enterprise data projects."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (2 to 8 lowercase chars) for enterprise projects and datasets."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
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

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for storage, governance, and BigQuery compute."
}

variable "dr_region" {
  type        = string
  default     = null
  description = "Optional disaster recovery GCP region for secondary dataset targets."
}

variable "enable_dr_datasets" {
  type        = bool
  default     = false
  description = "Whether to provision secondary BigQuery datasets in dr_region."
}

variable "kms_key_id" {
  type        = string
  default     = ""
  description = "Optional regional CMEK crypto key resource ID from foundation stage 02."
}

variable "dr_kms_key_id" {
  type        = string
  default     = ""
  description = "Optional secondary DR CMEK crypto key resource ID from foundation stage 02."
}

variable "shared_vpc_host_project_id" {
  type        = string
  default     = ""
  description = "Optional Shared VPC host project ID from foundation stage 02."
}

variable "vpc_id" {
  type        = string
  default     = ""
  description = "Optional VPC network resource ID linked from foundation stage 02."
}

variable "subnet_id" {
  type        = string
  default     = ""
  description = "Optional private subnetwork resource ID linked from foundation stage 02."
}

variable "datastream_network_attachment_id" {
  type        = string
  default     = ""
  description = "Optional Datastream PSC network attachment ID linked from stage 02."
}

variable "vpc_sc_perimeter_name" {
  type        = string
  default     = ""
  description = "Optional full VPC-SC service perimeter name for additive data project attachment."
}

variable "enforce_vpc_sc" {
  type        = bool
  default     = false
  description = "Whether the VPC-SC perimeter is in enforced mode instead of dry-run mode."
}

variable "domain_marts" {
  type        = set(string)
  default     = ["fin"]
  description = "Short domain codes for dedicated Gold mart storage projects."

  validation {
    condition     = length(var.domain_marts) >= 1 && alltrue([for d in var.domain_marts : can(regex("^[a-z0-9]{2,6}$", d))])
    error_message = "domain_marts must have at least one 2-6 character lowercase alphanumeric code."
  }
}

variable "primary_domain" {
  type        = string
  default     = "fin"
  description = "Primary domain code in var.domain_marts used for primary Gold outputs."
}

variable "masking_expression" {
  type        = string
  default     = "LAST_FOUR_CHARACTERS"
  description = "BigQuery predefined data masking expression attached to pii_masked."
}

variable "immutable_image_tags" {
  type        = bool
  default     = true
  description = "Whether Artifact Registry enforces immutable Docker image tags in prod."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether storage and compute folders enforce deletion protection."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes tables, repositories, and landing objects."
}

variable "ephemeral_table_expiration_ms" {
  type        = number
  default     = 7776000000
  description = "Default table expiration in ms for quarantine and assertion datasets (90 days)."
}

variable "ephemeral_partition_expiration_ms" {
  type        = number
  default     = 7776000000
  description = "Default partition expiration in ms for quarantine and assertion datasets (90 days)."
}

variable "enable_reservations" {
  type        = bool
  default     = true
  description = "Whether to provision BigQuery Enterprise slot reservations."
}

variable "baseline_slots" {
  type        = number
  default     = 0
  description = "Reference baseline slots setting for environment template overrides."
}

variable "max_slots" {
  type        = number
  default     = 100
  description = "Reference max autoscale slots setting for environment template overrides."
}

variable "etl_baseline_slots" {
  type        = number
  default     = null
  description = "Optional baseline slot capacity override for the ETL reservation."
}

variable "etl_max_slots" {
  type        = number
  default     = null
  description = "Optional autoscale max_slots override for the ETL reservation."
}

variable "bi_baseline_slots" {
  type        = number
  default     = null
  description = "Optional baseline slot capacity override for the BI reservation."
}

variable "bi_max_slots" {
  type        = number
  default     = null
  description = "Optional autoscale max_slots override for the BI reservation."
}

variable "adhoc_baseline_slots" {
  type        = number
  default     = null
  description = "Optional baseline slot capacity override for the adhoc reservation."
}

variable "adhoc_max_slots" {
  type        = number
  default     = null
  description = "Optional autoscale max_slots override for the adhoc reservation."
}

variable "reservation_assignments" {
  type        = map(string)
  default     = {}
  description = "Optional extra or override reservation assignments keyed by project ID."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after project API activation and KMS IAM grants."
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

variable "bi_analysts" {
  type        = list(string)
  default     = []
  description = "BI analyst principals granted Gold viewer access, jobUser on data-bi, and masked reads."
}

variable "bi_analysts_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string for BI analysts."
}

variable "data_engineers_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string for data engineers."
}

variable "governance_stewards_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string for data governance stewards."
}

variable "break_glass_admins_group" {
  type        = string
  default     = ""
  description = "Optional Google Group email or member string for break-glass emergency admins."
}

variable "batch_loader_sa_email" {
  type        = string
  default     = ""
  description = "Optional Cloud Run batch loader service account granted Artifact Registry reader and VPC-SC ingress."
}

variable "dataform_sa_email" {
  type        = string
  default     = ""
  description = "Optional Dataform service account email added to the VPC-SC ingress policy."
}

variable "finops_tag_value_ids" {
  type        = map(string)
  default     = {}
  description = "Optional Resource Manager FinOps tag value IDs linked from stage 01."
}

variable "labels" {
  type = map(string)
  default = {
    environment = "enterprise"
    managed_by  = "terraform"
  }
  description = "Labels applied to enterprise data platform resources."
}
