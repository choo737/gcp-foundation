# Governance Catalog Module

This module creates column-level access controls and a business glossary in GCP.

## Resources Managed

- One Data Catalog taxonomy with fine-grained access control enabled.
- Two policy tags: `pii_restricted` and `pii_masked`.
- One BigQuery data masking policy (`LAST_FOUR_CHARACTERS` by default) attached to `pii_masked`.
- Optional IAM bindings for masked readers and fine-grained readers.
- One optional Dataplex business glossary.

## Required APIs

Enable these APIs on the target project, or set `enable_apis = true`:

- `datacatalog.googleapis.com`
- `bigquerydatapolicy.googleapis.com`
- `dataplex.googleapis.com`

## Usage

```hcl
module "governance_catalog" {
  source = "../../modules/data/governance-catalog"

  project_id     = var.project_id
  region         = var.region
  prefix         = "bqfnd"
  masked_readers = ["user:analyst@example.com"]
}
```
