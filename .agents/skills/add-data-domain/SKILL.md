---
name: add-data-domain
description: Add a new Gold mart storage project domain (for example retail or ops) to data/enterprise/01-platform.
---

# Add Data Domain

Add isolated domain Gold mart projects without changing core Bronze or Silver storage.

## Steps

1. Choose a short 2-6 character lowercase domain code such as `ret` or `ops`.
2. Verify `${prefix}-${project_suffix}-dp-st-<domain>` stays within 30 characters.
3. Add the domain code to `domain_marts` in `data/enterprise/01-platform/terraform.tfvars`.
4. Run `terraform -chdir=data/enterprise/01-platform plan` to verify the new project, KMS grant, and `gold_mart` dataset.
5. Re-run `make fmt-check`, `make validate`, and `make test` before committing defaults.
