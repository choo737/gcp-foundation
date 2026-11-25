# Logging Guardrails Module

This module configures audit logging, Log Analytics, notifications, Essential Contacts, IAM viewers, and Org Policies.

## Resources Managed

- `google_logging_project_bucket_config` with Log Analytics enabled and a 1095-day retention default.
- Optional `google_logging_linked_dataset` exposing audit logs in BigQuery.
- Optional org or folder log sinks (`google_logging_organization_sink` or `google_logging_folder_sink`) for audit logs and SIEM export.
- Optional org or folder SCC notification config (`google_scc_v2_organization_notification_config` or `google_scc_v2_folder_notification_config`).
- Optional `google_essential_contacts_contact` entries and least-privilege org or folder viewer IAM bindings.
- Optional 38-policy `google_org_policy_policy` baseline gated by `enable_org_policies`.

## Org Policy Baseline (38 Policies)

Setting `enable_org_policies = true` enforces up to 38 organization or folder constraints across four groups.
Populate `allowed_policy_member_domains` and `allowed_contact_domains` to activate both domain policies.

| Group | Count | Enforced Constraints |
| --- | --- | --- |
| Identity & Cross-Domain | 8 | `iam.disableServiceAccountKeyCreation`, `iam.disableServiceAccountKeyUpload`, `iam.automaticIamGrantsForDefaultServiceAccounts`, `iam.disableAuditLoggingExemption`, `iam.restrictCrossProjectServiceAccountLienRemoval`, `iam.allowServiceAccountCredentialLifetimeExtension`, `iam.allowedPolicyMemberDomains`, `essentialcontacts.allowedContactDomains` |
| Data, Storage & AI | 9 | `storage.uniformBucketLevelAccess`, `storage.publicAccessPrevention`, `storage.secureHttpTransport`, `storage.restrictAuthTypes`, `sql.restrictPublicIp`, `sql.restrictAuthorizedNetworks`, `bigquery.disableBQOmniAWS`, `bigquery.disableBQOmniAzure`, `ainotebooks.restrictPublicIp` |
| Compute Guardrails | 7 | `compute.requireShieldedVm`, `compute.skipDefaultNetworkCreation`, `compute.requireOsLogin`, `compute.disableSerialPortAccess`, `compute.disableGuestAttributesAccess`, `compute.disableNestedVirtualization`, `compute.disableVpcExternalIpv6` |
| Network Guardrails | 7 | `compute.disableInternetNetworkEndpointGroup`, `compute.setNewProjectDefaultToZonalDNSOnly`, `compute.restrictXpnProjectLienRemoval`, `compute.vmExternalIpAccess`, `compute.vmCanIpForward`, `compute.restrictProtocolForwardingCreationForTypes`, `gcp.resourceLocations` |
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
