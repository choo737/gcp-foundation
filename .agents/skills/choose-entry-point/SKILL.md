---
name: choose-entry-point
description: Select between data/sandbox, greenfield foundation + data/enterprise, or brownfield data/enterprise based on user GCP permissions.
---

# Choose Entry Point

Pick the lowest-friction stage path that matches the user's GCP permissions and environment.

## Decision Table

1. Use `foundation/00-bootstrap` (`Path 0`) first when CI/CD requires GCS `tfstate` and GitHub OIDC WIF.
2. Use `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> optional `03-data-science` -> `02-governance-ops` -> optional `apps/enterprise` (`Path 1`) for greenfield orgs.
3. Start at `data/enterprise/01-platform` (`Path 2`) when an existing landing zone provides `data_folder_id`.
4. Use `data/sandbox/` (`Path 3`) when the user has one GCP project for fast validation.

## Checklist

- Confirm `billing_account` and `parent_id` or `data_folder_id` before running `terraform plan`.
- Set `enable_org_policies = false` if the caller lacks Org Policy Admin.
- Set `enable_reservations = false` if BigQuery slot quota is unavailable.
- Chain stages with `scripts/link-stages.sh` rather than duplicating variables manually.
