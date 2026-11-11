# Logging Guardrails Module

This module sets up regional audit logging, Data Access audit logs, and Org Policy guardrails.

## Resources Managed

- `google_logging_project_bucket_config` in `audit_project_id` with a 1095-day retention default.
- Optional `google_logging_folder_sink` and `roles/logging.bucketWriter` IAM grant.
- Folder `google_folder_iam_audit_config` entries for Cloud KMS, Storage, Secret Manager, and Data Catalog.
- Optional `google_org_policy_policy` rules gated by `enable_org_policies`.

## Org Policy Baseline (34 Policies)

Setting `enable_org_policies = true` enforces up to 34 folder constraints across four groups.
Populate `allowed_policy_member_domains` and `allowed_contact_domains` to activate both domain policies.

| Group | Count | Enforced Constraints |
| --- | --- | --- |
| Identity & Cross-Domain | 8 | `iam.disableServiceAccountKeyCreation`, `iam.disableServiceAccountKeyUpload`, `iam.automaticIamGrantsForDefaultServiceAccounts`, `iam.disableAuditLoggingExemption`, `iam.restrictCrossProjectServiceAccountLienRemoval`, `iam.allowServiceAccountCredentialLifetimeExtension`, `iam.allowedPolicyMemberDomains`, `essentialcontacts.allowedContactDomains` |
| Data, Storage & AI | 9 | `storage.uniformBucketLevelAccess`, `storage.publicAccessPrevention`, `storage.secureHttpTransport`, `storage.restrictAuthTypes`, `sql.restrictPublicIp`, `sql.restrictAuthorizedNetworks`, `bigquery.disableBQOmniAWS`, `bigquery.disableBQOmniAzure`, `ainotebooks.restrictPublicIp` |
| Compute & Network | 12 | `compute.requireShieldedVm`, `compute.skipDefaultNetworkCreation`, `compute.requireOsLogin`, `compute.disableSerialPortAccess`, `compute.disableGuestAttributesAccess`, `compute.disableNestedVirtualization`, `compute.disableVpcExternalIpv6`, `compute.disableInternetNetworkEndpointGroup`, `compute.setNewProjectDefaultToZonalDNSOnly`, `compute.vmExternalIpAccess`, `compute.vmCanIpForward`, `gcp.resourceLocations` |
| Serverless & CI | 5 | `cloudbuild.disableCreateDefaultServiceAccount`, `run.managed.requireInvokerIam`, `container.managed.enablePrivateNodes`, `run.allowedIngress`, `cloudfunctions.allowedIngressSettings` |

## Usage

```hcl
module "logging_guardrails" {
  source = "../../modules/foundation/logging-guardrails"

  audit_project_id = module.audit_project.project_id
  folder_id        = module.folders.root_folder_id
  prefix           = "ent"
  region           = var.region
}
```
