variable "project_id" {
  type        = string
  description = "Globally unique GCP project ID (6 to 30 characters)."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be 6-30 lowercase letters, digits, or hyphens."
  }
}

variable "project_name" {
  type        = string
  default     = ""
  description = "Optional display name for the GCP project."
}

variable "folder_id" {
  type        = string
  description = "Parent folder ID (numeric or folders/<id>)."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID attached to the project."
}

variable "deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."

  validation {
    condition     = contains(["PREVENT", "DELETE", "ABANDON"], var.deletion_policy)
    error_message = "deletion_policy must be PREVENT, DELETE, or ABANDON."
  }
}

variable "activate_apis" {
  type        = set(string)
  default     = []
  description = "Google Cloud service APIs enabled on the project."
}

variable "service_accounts" {
  type = map(object({
    display_name = string
    description  = optional(string, "")
  }))
  default     = {}
  description = "Optional service accounts created inside the project."
}

variable "project_iam_bindings" {
  type = map(object({
    role   = string
    member = string
  }))
  default     = {}
  description = "Non-authoritative IAM member bindings applied at project scope."
}

variable "tag_bindings" {
  type        = map(string)
  default     = {}
  description = "Optional map of tag keys to Resource Manager tagValues/<id> bound to this project."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to the GCP project."
}
