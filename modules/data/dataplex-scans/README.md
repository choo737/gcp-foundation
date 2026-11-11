# Dataplex Scans Module

This module creates on-demand Dataplex data profile scans for BigQuery tables.

## Resources Managed

- `google_dataplex_datascan` configured with `on_demand` trigger and `data_profile_spec`.

## Usage

```hcl
module "dataplex_scans" {
  source = "../../modules/data/dataplex-scans"

  project_id = var.project_id
  region     = var.region
  prefix     = "bqfnd"

  profile_tables = {
    customers = {
      project_id = var.project_id
      dataset_id = "bqfnd_silver_curated"
      table_id   = "masked_customers_canary"
    }
  }
}
```
