---
name: add-workload-pillar
description: Add a new workload folder under 02-environments or workload_folders alongside data-platform without breaking symmetry.
---

# Add Workload Pillar

Extend `02-environments` and `workload_folders` for new platform domains such as AI, app hosting, or sandbox workloads.

## Steps

1. Decide whether the pillar lives per environment under `02-environments/<env>` (`environment_folder_ids`) or as a shared folder in `workload_folders`.
2. For shared pillars, add the folder name to `workload_folders` on `module.folder_hierarchy` inside `foundation/01-org-governance/main.tf`.
3. For environment-scoped pillars, read `environment_folder_ids["<env>"]` from `foundation/01-org-governance/outputs.tf` via `scripts/link-stages.sh`.
4. Create the runnable stage directory obeying the 7-file contract (`README.md`, `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`, `terraform.tfvars.example`, `.terraform.lock.hcl`) plus `envs/`.
5. Keep reusable modules strictly inside `modules/<pillar>/<module>/` obeying the 5-file symmetry contract.
6. Add the new runnable stage to `ROOTS` in `Makefile` and run `make validate` and `make test`.
