# Enterprise Data Stage 03: Data Science & Regulated XAI

This optional stage provisions experimentation and MLOps projects, hardened Workbench instances, and XAI audit ledgers.

## Resources Deployed

- Separate `ds-exp` and `ml-ops` projects in tier `M` or `L` (co-located in `data-etl` for tier `S`).
- Separation-of-duties IAM restricting `ml-ops` analysts to `roles/aiplatform.viewer` and `pii_masked` reads only.
- Hardened Vertex AI Workbench instances, Docker `<prefix>-ml-cpr` registry, and Vertex AI Metadata Store.
- Locked WORM XAI bucket, 18-column `ml_xai_audit_ledger`, and Dataplex SHAP additivity AutoDQ scan.

## Usage

```bash
../../../scripts/link-stages.sh --env dev \
  ../../../foundation/01-org-governance ../../../foundation/02-security-network ../01-platform .
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=data/enterprise/03-data-science/dev"
terraform plan -var-file=envs/dev.tfvars.example
```
