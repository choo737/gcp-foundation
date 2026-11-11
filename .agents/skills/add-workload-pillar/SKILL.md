---
name: add-workload-pillar
description: Add a new workload folder under 02-workloads alongside data-platform without breaking folder hierarchy symmetry.
---

# Add Workload Pillar

Extend `02-workloads` for new platform domains such as AI, app hosting, or sandbox workloads.

## Steps

1. Pass the new folder name in `workload_folders` on `module.folder_hierarchy` inside `foundation/01-org-governance/main.tf`.
2. Export the new folder ID in `foundation/01-org-governance/outputs.tf` using `module.folder_hierarchy.workload_folder_ids["<pillar>"]`.
3. Create a matching runnable stage directory obeying the 6-file symmetry contract.
4. Keep reusable modules strictly inside `modules/<pillar>/<module>/` obeying the 5-file symmetry contract.
5. Add the new runnable stage to `ROOTS` in `Makefile` and run `make validate` and `make test`.
