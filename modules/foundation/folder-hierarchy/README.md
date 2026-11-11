# Folder Hierarchy Module

This module creates the top-level shared infrastructure and workload folder hierarchy.

## Resources Managed

- Optional root folder (`${prefix}-gcp-foundation` or `${prefix}-${folder_suffix}-gcp-foundation`).
- `01-shared-infrastructure` folder for audit, security, and network projects.
- `02-workloads` folder with workload pillar subfolders such as `data-platform`.

## Usage

```hcl
module "folders" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id           = "organizations/123456789012"
  prefix              = "ent"
  deletion_protection = true
}
```
