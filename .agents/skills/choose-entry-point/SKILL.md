---
name: choose-entry-point
description: Select between data/sandbox, greenfield foundation + data/enterprise, or brownfield data/enterprise based on user GCP permissions.
---

# Choose Entry Point

Pick the lowest-friction stage path that matches the user's GCP permissions and environment.

## Decision Table

1. Use `data/sandbox/` when the user only has one project and wants fast validation.
2. Use `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/` when building from an organization or top folder.
3. Start at `data/enterprise/01-platform` when an existing landing zone already provides `data_folder_id`.

## Checklist

- Confirm `billing_account` and `parent_id` or `data_folder_id` before running `terraform plan`.
- Set `enable_org_policies = false` if the caller lacks Org Policy Admin.
- Set `enable_reservations = false` if BigQuery slot quota is unavailable.
- Chain stages with `scripts/link-stages.sh` rather than duplicating variables manually.
