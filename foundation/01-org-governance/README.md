# Foundation Stage 01: Org Governance

This stage deploys folders, the audit project, locked logging, FinOps, and Security Command Center.

## Resources Deployed

- Root, `01-shared-infrastructure`, `02-workloads`, and `02-environments/{dev,staging,prod}` folders.
- `${prefix}-audit` project protected by a Resource Manager deletion lien.
- Locked central audit log bucket with Log Analytics and BigQuery linked dataset.
- Optional SIEM Pub/Sub sink, Essential Contacts, and viewer IAM groups.
- Optional 36-policy Org Policy baseline plus FinOps budget, export dataset, and tag bindings.
- Tiered Security Command Center wiring via `modules/foundation/scc-secops` (`NONE`, `STANDARD`, or `PREMIUM`).

## Tiered Security Command Center

Google deprecated the SCC Enterprise tier in May 2026.
Only `STANDARD` (free) and `PREMIUM` (paid) remain active tiers.

- `STANDARD` deploys regional BigQuery findings export (`var.region`), Pub/Sub alerts, Monitoring policy, and non-prod mutes.
- `PREMIUM` adds Custom SHA CEL modules (`prod` BigQuery CMEK and GCS UBLA) and optional Security Posture drift checks.
- Set `scc_location` (`global`, `us`, `eu`, or `sa`) for SCC v2 APIs; BigQuery data stays in `var.region`.
- Setting legacy `enable_scc_notifications = true` promotes `scc_tier = "NONE"` to `"STANDARD"` automatically.

## Org Policy Guardrails

Set `enable_org_policies = true` to enforce 34 default folder policies out of the box.
Add `allowed_policy_member_domains` and `allowed_contact_domains` to activate all 36 policies.
Set `dr_region` to add a second region to `gcp.resourceLocations`.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=foundation/01-org-governance/shared"
terraform plan
terraform apply
```
