# Folder Hierarchy Module

This module creates shared infrastructure, workload pillar, and multi-environment folder trees.

## Resources Managed

- Optional root folder (`${prefix}-gcp-foundation` or `${prefix}-${folder_suffix}-gcp-foundation`).
- `01-shared-infrastructure` folder for audit, security, and network projects.
- `02-workloads` folder with workload pillar subfolders such as `data-platform`.
- `02-environments` folder with `dev`, `staging`, and `prod` trees (`data-platform/{storage,compute}`).

## Usage

```hcl
module "folder_hierarchy" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id    = "organizations/000000000000"
  prefix       = "ent"
  environments = ["dev", "staging", "prod"]
}
```
