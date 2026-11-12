# Foundation Stage 01: Org Governance

This stage deploys the folder tree, audit project, logging sink, and FinOps guardrails.

## Resources Deployed

- Root, `01-shared-infrastructure`, `02-workloads`, and `data-platform` folders.
- `${prefix}-audit` project with Logging, Org Policy, Billing Budgets, Pub/Sub, BigQuery, and Essential Contacts APIs.
- Central audit log bucket with Log Analytics and BigQuery linked dataset.
- Optional SIEM Pub/Sub sink, SCC v2 high/critical notification topic, Essential Contacts, and viewer IAM groups.
- Optional 36-policy Org Policy baseline plus FinOps budget, export dataset, and cost-allocation tags.

## Org Policy Guardrails

Set `enable_org_policies = true` to enforce 34 default folder policies out of the box.
Add `allowed_policy_member_domains` and `allowed_contact_domains` to activate all 36 Enterprise baseline policies.

- Enforces Domain Restricted Sharing, Essential Contacts domains, and regional resource locations.
- Blocks Cloud SQL public IPs, VM external IPs, SA keys, and HMAC storage auth.
- Restricts Cloud Run, Cloud Functions ingress, Shared VPC lien removal, and external protocol forwarding.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```
