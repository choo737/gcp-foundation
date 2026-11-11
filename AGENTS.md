# Repository Agent Instructions

This repository holds Terraform modules and runnable stages for Google Cloud foundations and Medallion data platforms.

## Repository Layout

- `modules/foundation/`: Reusable modules (`folder-hierarchy`, `project-factory`, `logging-guardrails`, `finops-governance`, `network-security`).
- `modules/data/`: Reusable modules (`governance-catalog`, `bigquery-dataset`, `bigquery-reservations`, `dataplex-scans`, `dataform-repository`).
- `foundation/`: Stages `01-org-governance` and `02-security-network`.
- `data/sandbox/`: Single-project Medallion deployment root.
- `data/enterprise/`: Multi-project stages `01-platform` and `02-governance-ops`.
- `scripts/link-stages.sh`: Links Terraform outputs from upstream stages into downstream `00_linked.auto.tfvars.json`.

## Interactive Customer Setup Protocol

Always load `.agents/skills/setup-customer-foundation/SKILL.md` when helping a user deploy this repository.

1. **Create a private repo first**: Never use public forks; run `gh repo create --private` and verify `isPrivate == true`.
2. **Ask the customer first**: Never guess org IDs, billing accounts, project IDs, or IAM principals.
3. **Confirm path and lifecycle**: Ask for Path 1, Path 2, or Path 3, plus production vs test flags.
4. **Validate prefix and suffix**: Keep `prefix` to 3-6 chars and set `project_suffix` (`dev01`) to avoid 30-day soft-delete collisions.
5. **Verify GCP auth**: Check `gcloud config get-value account` and support `GOOGLE_OAUTH_ACCESS_TOKEN` for named configs.
6. **Store inputs and secrets safely**: Write inputs to `custom.auto.tfvars` and store Dataform PATs only in Secret Manager.
7. **Link and verify**: Chain stages with `scripts/link-stages.sh`, seed test rows, verify masking, Dataplex, and Dataform `SUCCEEDED`.

## Hard Contracts

1. Every directory under `modules/*/*` must contain only `README.md`, `main.tf`, `variables.tf`, `outputs.tf`, and `versions.tf`.
2. Every runnable stage under `foundation/*`, `data/sandbox`, and `data/enterprise/*` must contain only those five files plus `terraform.tfvars.example`.
3. Every `versions.tf` must pin `required_version = ">= 1.8.0"` and `hashicorp/google` `version = ">= 8.0.0, < 9.0.0"`.
4. Never commit real GCP project IDs, organization IDs, folder IDs, billing IDs, secrets, or personal handles.
5. Never commit `terraform.tfvars`, `custom.auto.tfvars`, `*.tfstate*`, `.terraform/`, or `00_linked.auto.tfvars.json`.
6. Keep project IDs within 30 characters and Dataform variables compatible with `https://github.com/choo737/gcp-data-medallion.git`.

## Verification Commands

```bash
make fmt-check
make validate
make test
```

## Available Repository Skills

- `.agents/skills/setup-customer-foundation/SKILL.md`
- `.agents/skills/choose-entry-point/SKILL.md`
- `.agents/skills/add-data-domain/SKILL.md`
- `.agents/skills/add-workload-pillar/SKILL.md`
- `.agents/skills/drift-safe-apply/SKILL.md`
