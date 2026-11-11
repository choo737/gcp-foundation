# Enterprise Data Stage 02: Governance Operations

This stage seeds Bronze tables, creates the Dataform repo, and configures Dataplex scans.

## Resources Deployed

- Seeded `pos_orders_cdc` and `crm_customers_cdc` tables in `data-core` with `pii_restricted` tags.
- Seeded `masked_customers_canary` table in `data-<primary_domain>` with `pii_masked` tags.
- Dedicated `ops_telemetry` dataset and `ops_job_cost_monitor` view inside `data-etl`.
- Cross-project Dataform repository and least-privilege IAM grants inside `data-etl`.
- On-demand Dataplex profile scan on `masked_customers_canary`.

## Usage

```bash
../../../scripts/link-stages.sh ../01-platform .
terraform init
terraform plan
terraform apply
```
