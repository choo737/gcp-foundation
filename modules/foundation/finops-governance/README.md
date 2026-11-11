# FinOps Governance Module

This module provisions Cloud Billing budgets, Pub/Sub alerts, billing export datasets, and cost tags.

## Provider Requirement

Pass a `google` provider configured with `user_project_override = true` and `billing_project = audit_project_id`.
This quota project setting avoids ADC billing-budget API errors.

## Resources Managed

- `google_pubsub_topic` for programmatic budget notifications.
- Optional `google_billing_budget` with 50%, 80%, 100% actual, and 110% forecasted rules.
- `google_bigquery_dataset` for Cloud Billing export plus `v_finops_audit_project_jobs` view.
- Resource Manager `cost_center` and `environment` tag keys and values parented to `audit_project_id`.

## Usage

```hcl
module "finops_governance" {
  source = "../../modules/foundation/finops-governance"

  providers = {
    google = google.billing_quota
  }

  audit_project_id       = module.audit_project.project_id
  billing_account        = var.billing_account
  prefix                 = var.prefix
  region                 = var.region
  budget_project_numbers = [module.audit_project.project_number]
}
```
