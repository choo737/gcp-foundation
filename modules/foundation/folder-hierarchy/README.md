# Folder Hierarchy Module

This module creates `shared-infrastructure` and multi-environment folder trees directly under `parent_id`.

## Resources Managed

- `shared-infrastructure` folder directly under `parent_id` (`organizations/<id>` or `folders/<id>`) for audit, security, and ops projects.
- `environments` folder directly under `parent_id` with `dev`, `uat` or `staging`, and `prod` trees (`data-platform/{storage,compute}`, `ai`, `app`, `network`).

## Usage

```hcl
module "folder_hierarchy" {
  source = "../../modules/foundation/folder-hierarchy"

  parent_id    = "organizations/000000000000"
  environments = ["dev", "staging", "prod"]
}
```
