# Foundation Stage 01: Org Governance

This stage deploys folders, the audit project, locked logging, and FinOps guardrails.

## Resources Deployed

- Root, `01-shared-infrastructure`, `02-workloads`, and `02-environments/{dev,staging,prod}` folders.
- `${prefix}-audit` project protected by a Resource Manager deletion lien.
- Locked central audit log bucket with Log Analytics and BigQuery linked dataset.
- Optional SIEM Pub/Sub sink, SCC v2 notification topic, Essential Contacts, and viewer IAM groups.
- Optional 36-policy Org Policy baseline plus FinOps budget, export dataset, and tag bindings.

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
