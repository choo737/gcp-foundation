# BigQuery Dataset Module

This module creates a BigQuery dataset with optional KMS encryption and IAM roles.

## Resources Managed

- One `google_bigquery_dataset` resource.
- Optional `default_encryption_configuration` block when `kms_key_name` is set.
- Non-authoritative dataset IAM bindings for `readers` and `editors`.

## Usage

```hcl
module "bronze_dataset" {
  source = "../../modules/data/bigquery-dataset"

  project_id                 = var.project_id
  dataset_id                 = "bqfnd_bronze_raw"
  region                     = var.region
  delete_contents_on_destroy = false
}
```
