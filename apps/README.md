# Application Stages

This directory hosts per-environment application workload factory stages wired into the shared landing zone.

## Included Stages

| Stage | Scope | Purpose | Status |
| --- | --- | --- | --- |
| `apps/enterprise` | Multi-env (`dev`, `uat`, `prod`) | Per-app folders, isolated GCP projects, Shared VPC subnets, CMEK, IAM | Active |
| `apps/sandbox` | Single-project trial | Co-located pilot option using `data/sandbox` or `gcp-webapp` | Planned |

## Linking Inputs

Run `scripts/link-stages.sh` from `foundation/01-org-governance` and `foundation/02-security-network` into `apps/enterprise`.
See [apps/enterprise/README.md](enterprise/README.md) for required variables and outputs.
