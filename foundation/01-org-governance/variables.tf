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

variable "dr_region" {
  type        = string
  default     = null
  description = "Optional disaster recovery GCP region added to allowed_resource_locations."
}

variable "environments" {
  type        = list(string)
  default     = ["dev", "staging", "prod"]
  description = "Environment folder names provisioned under 02-environments."
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
  default     = true
  description = "Whether to lock the central Cloud Logging audit bucket."
}

variable "enable_audit_project_lien" {
  type        = bool
  default     = true
  description = "Whether to attach a Resource Manager deletion lien to the audit project."
}

variable "enable_finops_tag_bindings" {
  type        = bool
  default     = true
  description = "Whether to bind FinOps cost-allocation tags onto the audit project."
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

variable "scc_tier" {
  type        = string
  default     = "NONE"
  description = "Security Command Center tier to wire (NONE, STANDARD, or PREMIUM)."

  validation {
    condition     = contains(["NONE", "STANDARD", "PREMIUM"], var.scc_tier)
    error_message = "scc_tier must be NONE, STANDARD, or PREMIUM."
  }
}

variable "scc_location" {
  type        = string
  default     = "global"
  description = "SCC v2 API location (global, us, eu, or sa). BigQuery findings export still stores rows in var.region."

  validation {
    condition     = contains(["global", "us", "eu", "sa"], var.scc_location)
    error_message = "scc_location must be global, us, eu, or sa."
  }
}

variable "enable_scc_notifications" {
  type        = bool
  default     = false
  description = "Legacy toggle promoting scc_tier to STANDARD when scc_tier is NONE."
}

variable "scc_notification_location" {
  type        = string
  default     = "global"
  description = "Legacy SCC v2 location fallback used when scc_location stays global."
}

variable "scc_alert_email_addresses" {
  type        = list(string)
  default     = []
  description = "Email addresses notified for unacknowledged HIGH and CRITICAL SCC findings."
}

variable "enable_security_posture" {
  type        = bool
  default     = false
  description = "Whether PREMIUM tier deploys a declarative Security Posture (requires organization_id)."
}

variable "organization_id" {
  type        = string
  default     = ""
  description = "Optional organization ID (organizations/<id> or <id>) for Security Posture when parent_id is a folder."
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
