variable "parent_id" {
  type        = string
  description = "Organization or parent folder ID formatted as organizations/<id> or folders/<id>."
}

variable "billing_account" {
  type        = string
  description = "Cloud Billing account ID linked to foundation projects."
}

variable "prefix" {
  type        = string
  default     = "ent"
  description = "Short prefix (2 to 8 lowercase chars) for folders and project IDs."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,6}[a-z0-9]$", var.prefix))
    error_message = "prefix must be 2-8 lowercase letters/digits/hyphens and start/end with alphanumeric."
  }
}

variable "project_suffix" {
  type        = string
  default     = ""
  description = "Optional short suffix (1 to 8 chars) for globally unique project and folder names."

  validation {
    condition     = var.project_suffix == "" || can(regex("^[a-z0-9]([a-z0-9-]{0,6}[a-z0-9])?$", var.project_suffix))
    error_message = "project_suffix must be empty or 1-8 lowercase alphanumeric characters."
  }
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region passed downstream."
}

variable "deletion_protection" {
  type        = bool
  default     = true
  description = "Whether folders enforce deletion protection."
}

variable "project_deletion_policy" {
  type        = string
  default     = "PREVENT"
  description = "Project deletion policy (PREVENT, DELETE, or ABANDON)."
}

variable "delete_contents_on_destroy" {
  type        = bool
  default     = false
  description = "Whether destroy drops FinOps BigQuery dataset contents and views."
}

variable "enable_org_policies" {
  type        = bool
  default     = false
  description = "Whether to enforce folder-level Org Policy guardrails."
}

variable "allowed_policy_member_domains" {
  type        = list(string)
  default     = []
  description = "Allowed Workspace customer IDs or principal sets for iam.allowedPolicyMemberDomains."
}

variable "allowed_contact_domains" {
  type        = list(string)
  default     = []
  description = "Allowed email domains for essentialcontacts.allowedContactDomains."
}

variable "denied_storage_auth_types" {
  type        = list(string)
  default     = ["in:ALL_HMAC_SIGNED_REQUESTS"]
  description = "Denied Cloud Storage auth types for storage.restrictAuthTypes."
}

variable "allowed_cloud_run_ingress" {
  type        = list(string)
  default     = ["is:internal-and-cloud-load-balancing"]
  description = "Allowed Cloud Run ingress settings for run.allowedIngress."
}

variable "allowed_cloud_functions_ingress" {
  type        = list(string)
  default     = ["is:ALLOW_INTERNAL_AND_GCLB"]
  description = "Allowed Cloud Functions ingress settings for cloudfunctions.allowedIngressSettings."
}

variable "allowed_protocol_forwarding_types" {
  type        = list(string)
  default     = ["is:INTERNAL"]
  description = "Allowed protocol forwarding types for compute.restrictProtocolForwardingCreationForTypes."
}

variable "retention_days" {
  type        = number
  default     = 1095
  description = "Retention period in days for central audit logs (3-year baseline)."
}

variable "lock_audit_bucket" {
  type        = bool
  default     = false
  description = "Whether to lock the central Cloud Logging audit bucket."
}

variable "enable_log_analytics" {
  type        = bool
  default     = true
  description = "Whether to enable Log Analytics on the central Cloud Logging audit bucket."
}

variable "enable_log_analytics_link" {
  type        = bool
  default     = true
  description = "Whether to link the Log Analytics audit bucket to a BigQuery dataset."
}

variable "enable_siem_pubsub_sink" {
  type        = bool
  default     = false
  description = "Whether to create an optional Pub/Sub sink for external SIEM ingestion."
}

variable "enable_scc_notifications" {
  type        = bool
  default     = false
  description = "Whether to stream HIGH and CRITICAL SCC v2 folder findings to Pub/Sub."
}

variable "scc_notification_location" {
  type        = string
  default     = "global"
  description = "Location ID for the Security Command Center v2 folder notification config."
}

variable "essential_contacts" {
  type = map(object({
    email        = string
    categories   = list(string)
    language_tag = optional(string, "en-US")
  }))
  default     = {}
  description = "Optional Essential Contacts mapped to the root foundation folder."
}

variable "foundation_iam_groups" {
  type        = map(string)
  default     = {}
  description = "Optional functional IAM groups (audit_viewer, security_reviewer, network_viewer, billing_viewer)."
}

variable "enable_data_access_audit_logs" {
  type        = bool
  default     = true
  description = "Whether to enable folder-level Data Access audit logs."
}

variable "enable_billing_budget" {
  type        = bool
  default     = true
  description = "Whether to create the foundation monthly Cloud Billing budget."
}

variable "budget_project_numbers" {
  type        = list(string)
  default     = []
  description = "Optional project numbers scoped by the monthly budget (empty covers the full billing account)."
}

variable "monthly_budget_amount" {
  type        = number
  default     = 500
  description = "Monthly FinOps budget threshold in whole currency units."
}

variable "budget_currency_code" {
  type        = string
  default     = "USD"
  description = "ISO-4217 currency code matching the billing account."
}

variable "propagation_wait_seconds" {
  type        = string
  default     = "30s"
  description = "Wait duration after API activation on newly created projects."
}

variable "labels" {
  type = map(string)
  default = {
    layer      = "foundation"
    managed_by = "terraform"
  }
  description = "Labels applied to foundation projects and FinOps resources."
}
