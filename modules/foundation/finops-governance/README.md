# FinOps Governance Module

This module provisions Cloud Billing budgets, email channels, Pub/Sub alerts, billing export datasets, and tags.

## Provider Requirement

Pass a `google` provider configured with `user_project_override = true` and `billing_project`.
This quota project setting avoids ADC billing-budget API errors.

## Resources Managed

- `google_pubsub_topic` for programmatic budget notifications.
- `google_monitoring_notification_channel` email channels (up to 5 per budget).
- Master, per-environment folder, and per-workload `google_billing_budget` resources (alert-only).
- `google_bigquery_dataset` defaulting to `"US"` for 2-month billing backfill, plus `v_finops_audit_project_jobs`.
- Resource Manager `cost_center` and `environment` tag keys and values.

## Usage

```hcl
module "finops_governance" {
  source = "../../modules/foundation/finops-governance"

  providers = {
    google = google.billing_quota
  }

  audit_project_id        = module.audit_project.project_id
  finops_project_id       = module.finops_project[0].project_id
  billing_account         = var.billing_account
  prefix                  = var.prefix
  region                  = var.region
  billing_export_location = "US"
  alert_email_addresses   = ["gcp-finops-alerts@example.com"]
}
```
