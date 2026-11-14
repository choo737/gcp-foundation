---
name: add-data-domain
description: Add a new Gold mart storage project domain (for example ret or ops) and re-link 01-platform into 02-governance-ops.
---

# Add Data Domain

Add isolated domain Gold mart projects without changing core Bronze or Silver storage.

## Steps

1. Choose a short 2-6 character lowercase alphanumeric domain code such as `ret` or `ops`.
2. Verify `${prefix}-${project_suffix}-data-<domain>` stays within 30 characters.
3. Add the domain code to `domain_marts` in `data/enterprise/01-platform/envs/<env>.tfvars` (or `custom.auto.tfvars`).
4. Run `make plan STAGE="data/enterprise/01-platform" ENV="${ENV}"` and apply to create the domain project, KMS grant, and `gold_mart` dataset.
5. Re-link `01-platform` outputs into `data/enterprise/02-governance-ops` using `./scripts/link-stages.sh --env "${ENV}" data/enterprise/01-platform data/enterprise/02-governance-ops`.
6. Apply `02-governance-ops` so `gold_<code>_project`, `gold_<code>_dataset` (plus `gold_retail_*` for `ret`), and VPC-SC attachment update automatically.
7. Re-run `make fmt-check`, `make validate`, and `make test` before committing defaults.
