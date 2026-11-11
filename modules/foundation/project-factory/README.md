# Project Factory Module

This module creates a GCP project without a default VPC network, enables APIs, and configures IAM.

## Resources Managed

- `google_project` with `auto_create_network = false`.
- `google_project_service` for each requested API.
- Optional `google_service_account` resources.
- Optional non-authoritative `google_project_iam_member` bindings.

## Usage

```hcl
module "audit_project" {
  source = "../../modules/foundation/project-factory"

  project_id      = "ent-audit"
  project_name    = "ent Audit FinOps"
  folder_id       = var.shared_infra_folder_id
  billing_account = var.billing_account
  activate_apis   = ["logging.googleapis.com"]
}
```
