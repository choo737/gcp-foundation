# Enterprise Data Stage 03: Data Science & Regulated XAI

This stage provisions `ds-exp`, `ml-ops`, and XAI audit ledgers.
It deploys hardened Agent Platform (formerly Vertex AI) Workbench instances.

## Resources Deployed

- Separate `ds-exp` and `ml-ops` projects in tier `M` or `L` (co-located in `data-core` for tier `S`).
- Separation-of-duties IAM restricting `ml-ops` analysts to `roles/aiplatform.viewer` and `pii_masked` reads only.
- Hardened Agent Platform Workbench instances, Docker `<prefix>-ml-cpr` registry, and Agent Platform ML Metadata Store.
- Locked WORM XAI bucket, 18-column `ml_xai_audit_ledger`, and Knowledge Catalog (formerly Dataplex) SHAP additivity Auto DQ scan.

## Usage

```bash
../../../scripts/link-stages.sh --env dev \
  ../../../foundation/01-org-governance ../../../foundation/02-security-network ../01-platform .
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=data/enterprise/03-data-science/dev"
terraform plan -var-file=envs/dev.tfvars.example
```
