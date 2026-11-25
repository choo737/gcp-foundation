variable "parent_id" {
  type        = string
  description = "Parent resource ID formatted as organizations/<id> or folders/<id>."

  validation {
    condition     = can(regex("^(organizations|folders)/[0-9]+$", var.parent_id))
    error_message = "parent_id must match organizations/<id> or folders/<id>."
  }
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether Google Cloud prevents folder deletion during destroy."
}

variable "environments" {
  type        = list(string)
  default     = ["dev", "uat", "prod"]
  description = "Environment folder names created under fldr-environments (for example [\"dev\", \"uat\", \"prod\"])."

  validation {
    condition = length(var.environments) > 0 && alltrue([
      for e in var.environments :
      can(regex("^[a-z0-9-]+$", e)) && length("fldr-${e}-data-platform") <= 30
    ])
    error_message = "environments must be non-empty lowercase alphanumeric/hyphen names so fldr-<env>-data-platform stays <= 30 chars."
  }
}

variable "create_data_subfolders" {
  type        = bool
  default     = false
  description = "When false, data projects sit directly under fldr-<env>-data-platform; when true, creates fldr-<env>-storage and fldr-<env>-compute subfolders."
}
