# Data Sandbox Root

This root deploys a single-project Medallion data platform for testing and validation.

## What It Deploys

- Required BigQuery, Data Catalog, Dataplex, Dataform, Secret Manager, and IAM APIs.
- Data Catalog taxonomy, `pii_restricted` tag, `pii_masked` tag, and `LAST_FOUR_CHARACTERS` masking policy.
- Four Medallion datasets: `bronze_raw`, `silver_curated`, `silver_assertions`, and `gold_mart`.
- Seeded `pos_orders_cdc` and `crm_customers_cdc` bronze tables plus `masked_customers_canary` in `gold_mart`.
- An `ops_job_cost_monitor` view over regional `INFORMATION_SCHEMA.JOBS_BY_PROJECT`.
- One Dataplex data profile scan on `masked_customers_canary`.
- One Dataform repository linked to the Medallion Git repo with least-privilege IAM.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Set `delete_contents_on_destroy = true` only for temporary canary runs that must destroy cleanly.
