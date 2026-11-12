# Multi-Environment Rollout and Decommissioning

This guide explains how to promote `dev`, `staging`, and `prod` safely and tear down protected environments.

## 1. Environment Promotion (`dev` -> `staging` -> `prod`)

Stage `01-org-governance` deploys once per foundation root and creates `02-environments/{dev,staging,prod}`.
Stages `02-security-network`, `01-platform`, and `02-governance-ops` deploy once per environment with separate remote state prefixes.

```bash
export TFSTATE_BUCKET="<prefix>-<suffix>-tfstate"

for ENV in dev staging prod; do
  ./scripts/link-stages.sh --env "${ENV}" foundation/01-org-governance foundation/02-security-network
  make apply STAGE="foundation/02-security-network" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"

  ./scripts/link-stages.sh --env "${ENV}" foundation/01-org-governance foundation/02-security-network data/enterprise/01-platform
  make apply STAGE="data/enterprise/01-platform" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"

  ./scripts/link-stages.sh --env "${ENV}" data/enterprise/01-platform data/enterprise/02-governance-ops
  make apply STAGE="data/enterprise/02-governance-ops" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"
done
```

Keep these per-environment defaults in `envs/<env>.tfvars`:

- `dev`: `project_suffix = "dev01"`, `deletion_protection = false`, `enforce_vpc_sc = false`, `enable_scheduled_workflow = false`.
- `staging`: `project_suffix = "stg01"`, `deletion_protection = false`, `enforce_vpc_sc = false`, `baseline_slots = 0`.
- `prod`: `project_suffix = "prd01"`, `deletion_protection = true`, `enforce_vpc_sc = true`, `immutable_image_tags = true`.

## 2. VPC-SC Dry-Run to Enforced Cutover

Start every environment with `enable_vpc_sc = true` and `enforce_vpc_sc = false`.
This creates an explicit dry-run perimeter spec without blocking live traffic.

Follow these four steps before enforcing a perimeter:

1. Run Cloud Workflows, Cloud Run ingestion, Dataform, Dataplex scans, and BI queries in `dev` and `staging`.
2. Inspect VPC-SC dry-run violations inside Log Analytics (`${prefix}_audit_logs`) in the audit project.
3. Add any missing service agents, CI WIF principals, or `vpc_sc_access_level_members`.
4. Flip `enforce_vpc_sc = true` across `02-security-network`, `01-platform`, and `02-governance-ops`, then run `make apply`.

## 3. Break-Glass Environment Decommissioning

Production deployments enable `deletion_protection = true`, `project_deletion_policy = "PREVENT"`, `lock_audit_bucket = true`, and project liens.
A locked Cloud Logging bucket cannot be deleted before its retention period expires.
Deleting a project with an active Resource Manager lien also fails.

Follow this exact break-glass order to decommission an environment:

### Step 1: Lower Data and Workload Protection Flags

Edit `envs/<env>.tfvars` or `custom.auto.tfvars` to set `deletion_protection = false`, `project_deletion_policy = "DELETE"`, and `delete_contents_on_destroy = true`.
Apply that flag update to `02-governance-ops`, `01-platform`, and `02-security-network` before running destroy.

```bash
for STAGE in data/enterprise/02-governance-ops data/enterprise/01-platform foundation/02-security-network; do
  make apply STAGE="${STAGE}" ENV="${ENV}" TFSTATE_BUCKET="${TFSTATE_BUCKET}"
done
```

### Step 2: Destroy Data and Security Stages in Reverse Order

Destroy `gcp-data-ingestion` before `gcp-foundation` so Cloud Run Direct VPC Egress jobs release Shared VPC addresses first.
Google Cloud holds `serverless-ipv4-cloudrun-*` internal IP reservations for roughly 60 minutes after deleting a Cloud Run job.
If Shared VPC detachment reports a linked `serverless-ipv4-cloudrun-*` address, retry `01-platform` and `02-security-network` destroy after it expires.

```bash
terraform -chdir=data/enterprise/02-governance-ops destroy
terraform -chdir=data/enterprise/01-platform destroy
terraform -chdir=foundation/02-security-network destroy
```

### Step 3: Remove Audit Lien and Locked Log Bucket State Before Parent Teardown

If tearing down the entire landing zone (`foundation/01-org-governance`):

1. Set `enable_audit_project_lien = false`, `deletion_protection = false`, `project_deletion_policy = "DELETE"`, and `delete_contents_on_destroy = true`.
2. Run `make apply STAGE="foundation/01-org-governance" ENV="shared" TFSTATE_BUCKET="${TFSTATE_BUCKET}"` to drop the lien.
3. Verify no liens remain on the audit project:

```bash
gcloud alpha resource-manager liens list --project="${AUDIT_PROJECT_ID}"
```

4. Because locked Cloud Logging buckets reject deletion API calls, remove the locked bucket resource from Terraform state:

```bash
terraform -chdir=foundation/01-org-governance state rm \
  'module.logging_guardrails.google_logging_project_bucket_config.audit'
```

5. Run `terraform -chdir=foundation/01-org-governance destroy` to remove the remaining folders and audit project.
6. Verify the GCS `tfstate` objects and increment `project_suffix` (`dev01` to `dev02`) before any rebuild.
