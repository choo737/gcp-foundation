# Entry Points Guide

Select one of three supported adoption paths based on your permissions and goals.

## 0. Create a Private Repository

Create a private repository before configuring customer IDs (`gh repo fork` remains public on GitHub):

```bash
gh repo create <owner>/<customer-repo> --private --template choo737/gcp-foundation --clone
gh repo view --json isPrivate --jq '.isPrivate'
```

## 1. Path 1: Greenfield Enterprise

Start at `foundation/01-org-governance` when building from an organization or top folder.

- Required permissions: Folder Admin, Project Creator, Billing User, and optional Org Policy Admin.
- Budget permissions: Grant Billing Account Costs Manager (`roles/billing.costsManager`) when `enable_billing_budget = true`.
- Without `roles/billing.costsManager`, set `enable_billing_budget = false` with standard Billing User permissions.
- Inputs: `parent_id`, `billing_account`, `region`, 3-6 char `prefix`, `project_suffix`, budget flags, and IAM principals.
- Order: `foundation/01-org-governance` -> `foundation/02-security-network` -> `data/enterprise/01-platform` -> `data/enterprise/02-governance-ops`.
- Link outputs between stages with `./scripts/link-stages.sh` into `00_linked.auto.tfvars.json`.

## 2. Path 2: Brownfield Enterprise

Start directly at `data/enterprise/01-platform` when an existing landing zone provides folders.

- Required inputs: `data_folder_id`, `billing_account`, `region`, `prefix`, and `project_suffix`.
- Optional inputs: `kms_key_id` for CMEK encryption on buckets and BigQuery datasets.
- Stage 01 creates `storage` and `compute` subfolders directly under `data_folder_id`.

## 3. Path 3: Sandbox Quickstart

Use `data/sandbox` when you have one GCP project and want fast Medallion validation.

- Required permissions: Project Owner or Editor plus IAM Admin on one project.
- Inputs: `project_id`, `region`, `prefix`, `masked_readers`, and optional `git_token_secret_version`.
- Leave `git_token_secret_version` empty for standalone Dataform, or supply a Secret Manager version for Git sync.
- Key outputs: Five datasets, `LAST_FOUR_CHARACTERS` masking tag, Dataplex scan, and Dataform repo.

## Production vs Ephemeral Lifecycle Flags

- Production defaults: `deletion_protection = true`, `project_deletion_policy = "PREVENT"`, `delete_contents_on_destroy = false`.
- Ephemeral overrides: `deletion_protection = false`, `project_deletion_policy = "DELETE"`, `delete_contents_on_destroy = true`.
- If switching from production flags, apply the override flags first, then destroy stages in reverse order.
- Increment `project_suffix` (for example `dev01` to `dev02`) before re-running after project deletion.
