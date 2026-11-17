# Enterprise Data Stage 01: Platform Topology

This stage deploys separated governance, storage, and compute projects under environment or data folders.

## Works Greenfield or Brownfield

- Chained after `foundation/`: resolves `02-environments/<env>/data-platform/{storage,compute}` automatically.
- Brownfield standalone: pass any existing `data_folder_id` and `billing_account`.

## Resources Deployed

- Five projects: `data-gov`, `data-core`, `data-<domain>`, `data-etl`, and `data-bi`.
- Governance taxonomy, policy tags, `LAST_FOUR_CHARACTERS` masking policy, and Dataplex glossary.
- Versioned landing GCS bucket (soft delete, optional dual-region `ASYNC_TURBO`, `incoming/` lifecycle) and Artifact Registry repo.
- Custom `dataform_pipeline_runner` IAM roles without dataset update or delete permissions.
- Shared VPC service attachments, VPC-SC additive membership, and BigQuery `ENTERPRISE` or `ENTERPRISE_PLUS` reservations.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=data/enterprise/01-platform/dev"
terraform plan -var-file=envs/dev.tfvars.example
```
