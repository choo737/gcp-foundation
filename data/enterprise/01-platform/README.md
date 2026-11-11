# Enterprise Data Stage 01: Platform Topology

This stage deploys separated governance, storage, and compute projects under `data_folder_id`.

## Works Greenfield or Brownfield

- Chained after `foundation/`: link outputs from stages 01 and 02.
- Brownfield standalone: pass any existing `data_folder_id` and `billing_account`.

## Resources Deployed

- `storage` and `compute` subfolders inside `data_folder_id`.
- Five projects: `data-gov`, `data-core`, `data-<domain>`, `data-etl`, and `data-bi`.
- Governance taxonomy, policy tags, `LAST_FOUR_CHARACTERS` masking policy, and Dataplex glossary.
- Versioned landing GCS bucket and Medallion BigQuery datasets with optional CMEK encryption.
- BigQuery Enterprise autoscaling slot reservations (`etl`, `bi`, `adhoc`).
- BI analysts granted `jobUser` on `data-bi` and Gold `dataViewer` only.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```
