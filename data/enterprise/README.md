# Enterprise Data Stages

These three stages deploy an enterprise multi-project Medallion data platform and optional Data Science XAI stage.

## Stage Order

1. `01-platform/`: Provisions four default projects (or five with `split_etl_project`), datasets, KMS grants, and reservations.
2. `02-governance-ops/`: Seeds Bronze tables, links Dataform in `etl_compute_project_id`, grants IAM, and adds Knowledge Catalog scans.
3. `03-data-science/`: Provisions `ds-exp`, `ml-ops`, Agent Platform (formerly Vertex AI) Workbench, WORM bucket, and `ml_xai_audit_ledger`.

## Linking Upstream Stages

Chain from `foundation/` stages:

```bash
cd data/enterprise/01-platform
../../../scripts/link-stages.sh ../../../foundation/01-org-governance ../../../foundation/02-security-network .
terraform init
terraform apply
```

Then chain stage 01 into stage 02:

```bash
cd ../02-governance-ops
../../../scripts/link-stages.sh ../01-platform .
terraform init
terraform apply
```
