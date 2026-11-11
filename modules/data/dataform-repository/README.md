# Dataform Repository Module

This module creates a Dataform repository, release config, and optional workflow schedule.

## Resources Managed

- One dedicated `google_service_account` when `service_account_email` is empty.
- One `google_dataform_repository` with optional `git_remote_settings` and `kms_key_name`.
- One `google_dataform_repository_release_config` named `prod-main` pinned via `git_release_commitish`.
- One optional `google_dataform_repository_workflow_config` when `enable_scheduled_workflow` is true.

## Usage

```hcl
module "dataform_repository" {
  source = "../../modules/data/dataform-repository"

  project_id       = var.project_id
  region           = var.region
  prefix           = "bqfnd"
  repository_name  = "bqfnd-medallion"
  git_remote_url   = "https://github.com/choo737/gcp-data-medallion.git"
  bronze_dataset   = "bqfnd_bronze_raw"
  silver_dataset   = "bqfnd_silver_curated"
  gold_dataset     = "bqfnd_gold_mart"
  assertion_schema = "bqfnd_silver_assertions"
  pii_policy_tag   = module.governance_catalog.pii_masked_policy_tag_id
}
```
