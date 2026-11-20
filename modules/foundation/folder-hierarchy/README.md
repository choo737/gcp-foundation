# Folder Hierarchy Module

This module creates shared infrastructure, workload pillar, and multi-environment folder trees.

## Resources Managed

- Optional root folder (`${prefix}-gcp-foundation` or `${prefix}-${folder_suffix}-gcp-foundation`).
- `shared-infrastructure` folder for audit, security, and network projects.
- `workloads` folder with workload pillar subfolders such as `data-platform`.
- `environments` folder with `dev`, `uat` or `staging`, and `prod` trees (`data-platform/{storage,compute}`, `ai`, `app`, `network`).

## Usage

```hcl
module "folder_hierarchy" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id    = "organizations/000000000000"
  prefix       = "ent"
  environments = ["dev", "staging", "prod"]
}
```
