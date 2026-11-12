# Data Sandbox Root

This root deploys a single-project Medallion data platform for testing and validation.

## What It Deploys

- Required BigQuery, Artifact Registry, Data Catalog, Dataplex, Dataform, Cloud Run, and Storage APIs.
- Data Catalog taxonomy, `pii_restricted` tag, `pii_masked` tag, and `LAST_FOUR_CHARACTERS` masking policy.
- Versioned landing GCS bucket (`incoming/` lifecycle rule) and Docker Artifact Registry repository.
- Six datasets: `bronze_raw`, `silver_curated`, `silver_assertions`, `gold_mart`, `quarantine`, and `ops_telemetry`.
- Partitioned `pos_orders_cdc` and `crm_customers_cdc` bronze tables plus `masked_customers_canary`.
- Dataplex profile and `silver.fct_orders` data quality scans plus Dataform with custom IAM role.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend=false
terraform plan
terraform apply
```

Set `delete_contents_on_destroy = true` only for temporary canary runs that must destroy cleanly.
