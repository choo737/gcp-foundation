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
  description = "Short prefix (2 to 8 lowercase chars) for bootstrap buckets and WIF pool."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix)) && !startswith(var.prefix, "gcp-")
    error_message = "prefix must be 2-8 lowercase alphanumeric/hyphen chars and must not start with gcp-."
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

variable "enable_ci_service_accounts" {
  type        = bool
  default     = true
  description = "Whether to provision dedicated tf-foundation-ci, tf-ingestion-ci, and dataform-ci service accounts."
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
  description = "Optional GitHub Environments (dev, staging, prod) enforced in WIF CEL."
}

variable "ci_repository_map" {
  type        = map(list(string))
  default     = {}
  description = "Per-service-account GitHub repository allowlists (keys: tf_foundation_ci, tf_ingestion_ci, dataform_ci) preventing cross-repo impersonation."

  validation {
    condition = alltrue([
      for k, repos in var.ci_repository_map :
      contains(["tf_foundation_ci", "tf_ingestion_ci", "dataform_ci"], k) &&
      alltrue([for r in repos : can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", r))])
    ])
    error_message = "ci_repository_map keys must be tf_foundation_ci, tf_ingestion_ci, or dataform_ci, and values must match owner/repo."
  }
}

variable "service_account_bindings" {
  type = map(object({
    service_account_id = string
    repositories       = list(string)
  }))
  default     = {}
  description = "Optional WIF service account impersonation bindings mapped per repository."
}

variable "force_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy removes objects inside tfstate and iac-outputs buckets."
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
