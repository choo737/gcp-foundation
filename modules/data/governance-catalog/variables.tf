variable "project_id" {
  type        = string
  description = "GCP project ID that hosts governance resources."
}

variable "region" {
  type        = string
  description = "GCP region for taxonomy, data policy, and glossary resources."
}

variable "prefix" {
  type        = string
  description = "Resource name prefix used for taxonomy and policy IDs."
}

variable "environment" {
  type        = string
  default     = ""
  description = "Optional environment name included in the org-unique taxonomy display name."
}

variable "masking_expression" {
  type        = string
  default     = "LAST_FOUR_CHARACTERS"
  description = "BigQuery predefined data masking expression attached to pii_masked."

  validation {
    condition = contains([
      "LAST_FOUR_CHARACTERS",
      "FIRST_FOUR_CHARACTERS",
      "EMAIL_MASK",
      "DATE_YEAR_MASK",
      "DEFAULT_MASKING_VALUE",
      "ALWAYS_NULL",
    ], var.masking_expression)
    error_message = "masking_expression must be a non-hash BigQuery predefined masking expression."
  }
}

variable "masked_readers" {
  type        = list(string)
  default     = []
  description = "IAM members allowed to read masked PII column values."
}

variable "fine_grained_readers" {
  type        = list(string)
  default     = []
  description = "IAM members allowed to read unmasked PII columns."
}

variable "enable_glossary" {
  type        = bool
  default     = true
  description = "Whether to create a Dataplex business glossary."
}

variable "enable_apis" {
  type        = bool
  default     = false
  description = "Whether this module enables required governance APIs on the project."
}

variable "labels" {
  type        = map(string)
  default     = {}
  description = "Labels applied to supported governance resources."
}
