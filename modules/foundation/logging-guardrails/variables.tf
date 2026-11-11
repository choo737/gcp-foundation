variable "audit_project_id" {
  type        = string
  description = "Audit project ID hosting the central Cloud Logging bucket."
}

variable "folder_id" {
  type        = string
  description = "Target folder ID monitored by the sink and guardrails."
}

variable "prefix" {
  type        = string
  description = "Name prefix for log bucket and sink resources."
}

variable "region" {
  type        = string
  default     = "asia-southeast1"
  description = "Default GCP region for the audit log bucket."
}

variable "logging_location" {
  type        = string
  default     = null
  description = "Cloud Logging bucket location, defaulting to var.region."
}

variable "retention_days" {
  type        = number
  default     = 1095
  description = "Retention period in days for audit log entries (3-year baseline)."
}

variable "lock_audit_bucket" {
  type        = bool
  default     = false
  description = "Whether to lock the Cloud Logging audit bucket against deletion or shortening."
}

variable "enable_folder_sink" {
  type        = bool
  default     = true
  description = "Whether to create the aggregated folder log sink."
}

variable "enable_data_access_audit_logs" {
  type        = bool
  default     = true
  description = "Whether to enable folder-level Data Access audit logs for security-sensitive APIs."
}

variable "data_access_audit_services" {
  type = set(string)
  default = [
    "cloudkms.googleapis.com",
    "storage.googleapis.com",
    "secretmanager.googleapis.com",
    "datacatalog.googleapis.com",
  ]
  description = "APIs with ADMIN_READ, DATA_READ, and DATA_WRITE folder audit logging enabled."
}

variable "enable_org_policies" {
  type        = bool
  default     = false
  description = "Whether to apply optional folder-level Org Policy guardrails."
}

variable "boolean_org_policies" {
  type = set(string)
  default = [
    # Identity & Access
    "iam.disableServiceAccountKeyCreation",
    "iam.disableServiceAccountKeyUpload",
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "iam.disableAuditLoggingExemption",
    "iam.restrictCrossProjectServiceAccountLienRemoval",
    # Data, Databases, Storage & AI
    "storage.uniformBucketLevelAccess",
    "storage.publicAccessPrevention",
    "storage.secureHttpTransport",
    "sql.restrictPublicIp",
    "sql.restrictAuthorizedNetworks",
    "bigquery.disableBQOmniAWS",
    "bigquery.disableBQOmniAzure",
    "ainotebooks.restrictPublicIp",
    # Compute & Network Hardening
    "compute.requireShieldedVm",
    "compute.skipDefaultNetworkCreation",
    "compute.requireOsLogin",
    "compute.disableSerialPortAccess",
    "compute.disableGuestAttributesAccess",
    "compute.disableNestedVirtualization",
    "compute.disableVpcExternalIpv6",
    "compute.disableInternetNetworkEndpointGroup",
    "compute.setNewProjectDefaultToZonalDNSOnly",
    # Serverless, Containers & CI/CD
    "cloudbuild.disableCreateDefaultServiceAccount",
    "run.managed.requireInvokerIam",
    "container.managed.enablePrivateNodes",
  ]
  description = "Enforced boolean Org Policy constraints when enable_org_policies is true."
}

variable "deny_all_org_policies" {
  type = set(string)
  default = [
    "compute.vmExternalIpAccess",
    "compute.vmCanIpForward",
    "iam.allowServiceAccountCredentialLifetimeExtension",
  ]
  description = "List Org Policy constraints enforced with deny_all when enable_org_policies is true."
}

variable "allowed_resource_locations" {
  type        = list(string)
  default     = ["in:asia-southeast1-locations"]
  description = "Allowed GCP locations enforced when enable_org_policies is true."
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
