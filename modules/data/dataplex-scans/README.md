# Dataplex Scans Module

This module creates on-demand Dataplex data profile and data quality scans for BigQuery tables.

## Resources Managed

- `google_dataplex_datascan` profile resources with `data_profile_spec`.
- Optional `google_dataplex_datascan` quality resource with `data_quality_spec` targeting `silver.fct_orders`.
- Optional BigQuery results export when `quality_results_table` or `quarantine_dataset_id` is set.

## Usage

```hcl
module "dataplex_scans" {
  source = "../../modules/data/dataplex-scans"

  project_id                = var.project_id
  region                    = var.region
  prefix                    = "bqfnd"
  enable_quality_scan       = true
  quality_target_dataset_id = "bqfnd_silver_curated"
  quality_target_table_id   = "fct_orders"
}
```
