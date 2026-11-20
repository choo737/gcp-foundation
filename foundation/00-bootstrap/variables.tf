variable "project_id" {
  type        = string
  description = "Existing admin or seed GCP project ID hosting Terraform state and WIF."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for bootstrap Cloud Storage buckets."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (3 to 8 lowercase chars) for bootstrap buckets and WIF pool."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix)) && !startswith(var.prefix, "gcp-")
    error_message = "prefix must be 3-8 lowercase alphanumeric/hyphen chars and must not start with gcp-."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) for globally unique GCS bucket names."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "auto_unique_suffix" {
  type        = bool
  default     = false
  description = "When true and project_suffix is empty, appends a deterministic 4-hex code to bootstrap bucket names."
}

variable "foundation_sa_mode" {
  type        = string
  default     = "single"
  description = "Foundation CI service account mode: single (tf_foundation_ci) or per_stage (org_gov_ci, net_sec_ci, data_plat_ci, tf_app_ci)."

  validation {
    condition     = contains(["single", "per_stage"], var.foundation_sa_mode)
    error_message = "foundation_sa_mode must be single or per_stage."
  }
}

variable "enable_ci_service_accounts" {
  type        = bool
  default     = true
  description = "Whether to provision dedicated foundation, ingestion, and Dataform CI service accounts."
}

variable "enable_github_wif" {
  type        = bool
  default     = false
  description = "Whether to provision the GitHub Actions Workload Identity Pool and OIDC provider."
}

variable "github_org" {
  type        = string
  default     = ""
  description = "GitHub organization or owner login enforced by the WIF CEL condition."

  validation {
    condition     = var.github_org == "" || can(regex("^[A-Za-z0-9-]+$", var.github_org))
    error_message = "github_org must match ^[A-Za-z0-9-]+$ to prevent CEL injection."
  }
}

variable "github_repositories" {
  type        = list(string)
  default     = []
  description = "Authorized GitHub repositories (owner/repo) allowed to federate via WIF."

  validation {
    condition     = alltrue([for r in var.github_repositories : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", r))])
    error_message = "Each github_repositories entry must match owner/repo using safe characters only."
  }
}

variable "allowed_refs" {
  type        = list(string)
  default     = []
  description = "Optional Git refs or wildcard prefixes (for example refs/heads/main, refs/tags/*) enforced in WIF CEL."
}

variable "allowed_environments" {
  type        = list(string)
  default     = []
  description = "Optional GitHub Environments (shared, dev, uat, staging, prod) enforced in WIF CEL."
}

variable "ci_repository_map" {
  type        = map(list(string))
  default     = {}
  description = "Per-service-account GitHub repository allowlists (keys: tf_foundation_ci, org_gov_ci, net_sec_ci, data_plat_ci, tf_ingestion_ci, dataform_ci, tf_ds_ci, tf_app_ci, secops_ci, finops_ci) preventing cross-repo impersonation."

  validation {
    condition = alltrue([
      for k, repos in var.ci_repository_map :
      contains(["tf_foundation_ci", "org_gov_ci", "net_sec_ci", "data_plat_ci", "tf_ingestion_ci", "dataform_ci", "tf_ds_ci", "tf_app_ci", "secops_ci", "finops_ci"], k) &&
      alltrue([for r in repos : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", r))])
    ])
    error_message = "ci_repository_map keys must be tf_foundation_ci, org_gov_ci, net_sec_ci, data_plat_ci, tf_ingestion_ci, dataform_ci, tf_ds_ci, tf_app_ci, secops_ci, or finops_ci, and values must match owner/repo."
  }
}

variable "service_account_bindings" {
  type = map(object({
    service_account_id = string
    repositories       = list(string)
    environments       = optional(list(string), [])
  }))
  default     = {}
  description = "Optional WIF service account impersonation bindings mapped per repository and optional environments."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes objects inside tfstate and iac-outputs buckets."
}

variable "soft_delete_retention_seconds" {
  type        = number
  default     = 1209600
  description = "GCS soft-delete retention in seconds (1209600 = 14 days; 0 disables or 604800..7776000)."

  validation {
    condition     = var.soft_delete_retention_seconds == 0 || (var.soft_delete_retention_seconds >= 604800 && var.soft_delete_retention_seconds <= 7776000)
    error_message = "soft_delete_retention_seconds must be 0 or between 604800 (7 days) and 7776000 (90 days)."
  }
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation on the bootstrap project."
}

variable "labels" {
  type = map(string)
  default = {
    layer      = "foundation"
    stage      = "bootstrap"
    managed_by = "terraform"
  }
  description = "Labels applied to bootstrap GCS buckets."
}
