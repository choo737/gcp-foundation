# ML Governance Module

This module provisions hardened Vertex AI Workbench instances, MLOps artifacts, and XAI audit controls.

## Resources Managed

- Hardened `google_workbench_instance` nodes in `ds-exp` with private IPs, CMEK disks, and disabled root or downloads.
- Instance-scoped `roles/notebooks.admin` bindings per Workbench owner.
- Optional `google_colab_runtime_template` blocked automatically under `regulated_fsi_rmit`.
- Docker Artifact Registry `<prefix>-ml-cpr` and Vertex AI `default` Metadata Store in `ml-ops`.
- WORM Cloud Storage bucket `<ml_ops_project_id>-xai-worm` with `prod` retention lock.
- BigQuery dataset `<ds_prefix>_ml_xai_audit` and 18-column `ml_xai_audit_ledger` table.
- Dataplex AutoDQ scan validating SHAP additivity and model provenance digests.

## Usage

```hcl
module "ml_governance" {
  source = "../../modules/data/ml-governance"

  ds_exp_project_id          = var.ds_exp_project_id
  ml_ops_project_id          = var.ml_ops_project_id
  region                     = var.region
  prefix                     = "ent"
  environment                = "dev"
  workbench_runtime_sa_email = google_service_account.workbench_runtime[0].email
}
```
