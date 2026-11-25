# Folder Hierarchy Module

This module creates `fldr-coe` and multi-environment folder trees directly under `parent_id`.

## Resources Managed

- `fldr-coe` folder directly under `parent_id` (`organizations/<id>` or `folders/<id>`) for audit, security, and ops projects.
- `fldr-network` folder directly under `parent_id` for `prj-<env>-network-<suffix>` network host projects.
- `fldr-environments` folder under `parent_id` with `fldr-<env>` trees (`fldr-<env>-data-platform`, `fldr-<env>-ai-platform`, `fldr-<env>-app-platform`).

## Usage

```hcl
module "folder_hierarchy" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id    = "organizations/<YOUR_ORG_ID>"
  environments = ["dev", "uat", "prod"]
}
```
