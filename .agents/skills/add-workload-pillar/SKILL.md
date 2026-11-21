---
name: add-workload-pillar
description: Add a new workload folder under environments/<env> alongside data-platform without breaking symmetry.
---

# Add Workload Pillar

Extend `environments` for new platform domains such as AI, app hosting, or sandbox workloads.

## Steps

1. Decide whether the pillar lives per environment under `environments/<env>` (`environment_folder_ids`) or directly under `parent_id`.
2. For environment-scoped pillars, add the folder resource inside `modules/foundation/folder-hierarchy/main.tf` under `google_folder.env[each.key].name`.
3. Read `environment_folder_ids["<env>"]` from `foundation/01-org-governance/outputs.tf` via `scripts/link-stages.sh`.
4. Create the runnable stage directory obeying the 7-file contract (`README.md`, `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `terraform.tfvars.example`, `.terraform.lock.hcl`) plus `envs/`.
5. Keep reusable modules strictly inside `modules/<pillar>/<module>/` obeying the 5-file symmetry contract.
6. Add the new runnable stage to `ROOTS` in `Makefile` and run `make validate` and `make test`.
