---
name: drift-safe-apply
description: Safely link upstream stage outputs and handle existing GCP folders, APIs, or policy tags without destructive state replacements.
---

# Drift-Safe Apply

Follow this workflow when applying Terraform stages against live or pre-populated GCP environments.

## Steps

1. Link upstream outputs into `00_linked.auto.tfvars.json` using `./scripts/link-stages.sh <upstream_dir> <target_dir>`.
2. Always run `terraform plan` first and inspect every `replace` or `destroy` action.
3. Keep `deletion_protection = true` on folders and `deletion_policy = "PREVENT"` on production projects.
4. Use `terraform import` if a target folder, project, or dataset already exists before applying.
5. Keep `disable_on_destroy = false` on all `google_project_service` resources so teardown never breaks sibling workloads.
