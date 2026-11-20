# Enterprise Application Factory Stage

This stage provisions isolated application projects under `02-environments/<env>/app` using `modules/app/workload-factory`.

## Inputs Linked Upstream

Run `./scripts/link-stages.sh --env <env> foundation/01-org-governance foundation/02-security-network apps/enterprise` first.

- `environment_app_folder_ids`, `shared_artifact_registry_id`, and `finops_tag_value_ids` from `foundation/01-org-governance`.
- `shared_vpc_host_project_id`, `app_subnet_id` (mapped to `subnet_id`), `kms_key_id`, `vpc_sc_perimeter_name`, and `enforce_vpc_sc` from `foundation/02-security-network`.
