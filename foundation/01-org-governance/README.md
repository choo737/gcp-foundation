# Foundation Stage 01: Org Governance

This stage deploys the folder tree, audit project, logging sink, and FinOps guardrails.

## Resources Deployed

- Root, `01-shared-infrastructure`, `02-workloads`, and `data-platform` folders.
- `${prefix}-fnd-audit` project with Logging, Org Policy, Billing Budgets, Pub/Sub, and BigQuery APIs.
- Central audit log bucket, folder sink, and optional Org Policy rules.
- FinOps monthly budget, Pub/Sub alert topic, `billing_export` dataset, and cost-allocation tags.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```
