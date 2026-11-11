# Logging Guardrails Module

This module sets up regional audit logging, Data Access audit logs, and Org Policy guardrails.

## Resources Managed

- `google_logging_project_bucket_config` in `audit_project_id` with a 1095-day retention default.
- Optional `google_logging_folder_sink` and `roles/logging.bucketWriter` IAM grant.
- Folder `google_folder_iam_audit_config` entries for Cloud KMS, Storage, Secret Manager, and Data Catalog.
- Optional `google_org_policy_policy` rules gated by `enable_org_policies`.

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
