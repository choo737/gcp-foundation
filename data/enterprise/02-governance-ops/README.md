# Enterprise Data Stage 02: Governance Operations

This stage seeds partitioned Bronze tables, creates the Dataform repo, and configures Dataplex scans.

## Resources Deployed

- Partitioned `pos_orders_cdc`, `crm_customers_cdc`, and pre-seeded `silver.fct_orders` tables in `data-core`.
- Seeded `masked_customers_canary` table in `data-<primary_domain>` with `pii_masked` tags.
- Dedicated `ops_telemetry` dataset and `ops_job_cost_monitor` view inside `data-etl`.
- Cross-project Dataform repository bound to the custom `dataform_pipeline_runner` role.
- On-demand Dataplex profile and `silver.fct_orders` data quality scans.
- Optional VPC-SC runtime ingress policies for Dataform and Dataplex service identities.

## Usage

```bash
../../../scripts/link-stages.sh ../01-platform .
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=data/enterprise/02-governance-ops/dev"
terraform plan -var-file=envs/dev.tfvars.example
```
