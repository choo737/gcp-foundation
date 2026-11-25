---
name: add-workload-pillar
description: Add a new workload folder under fldr-environments/fldr-<env> alongside fldr-<env>-data-platform without breaking symmetry.
---

# Add Workload Pillar

Extend `fldr-environments` for new platform domains such as AI, app hosting, or sandbox workloads.

## Steps

1. Decide whether the pillar lives per environment under `fldr-environments/fldr-<env>` (`environment_folder_ids`) or directly under `parent_id`.
2. For environment-scoped pillars, add the folder resource inside `modules/foundation/folder-hierarchy/main.tf` under `google_folder.env[each.key].name`.
3. Read `environment_folder_ids["<env>"]` from `foundation/01-org-governance/outputs.tf` via `scripts/link-stages.sh`.
4. Create the runnable stage obeying the 7-file contract (TF files, `README.md`, lockfile, `tfvars` example) with `envs/`.
5. Keep reusable modules strictly inside `modules/<pillar>/<module>/` obeying the 5-file symmetry contract.
6. Add the new runnable stage to `ROOTS` in `Makefile` and run `make validate` and `make test`.
