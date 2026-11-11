# Foundation Stage 01: Org Governance

This stage deploys the folder tree, audit project, logging sink, and FinOps guardrails.

## Resources Deployed

- Root, `01-shared-infrastructure`, `02-workloads`, and `data-platform` folders.
- `${prefix}-audit` project with Logging, Org Policy, Billing Budgets, Pub/Sub, and BigQuery APIs.
- Central audit log bucket, folder sink, and optional 34-policy Org Policy baseline.
- FinOps monthly budget, Pub/Sub alert topic, `billing_export` dataset, and cost-allocation tags.

## Org Policy Guardrails

Set `enable_org_policies = true` to enforce 32 default folder policies out of the box.
Add `allowed_policy_member_domains` and `allowed_contact_domains` to activate all 34 Enterprise baseline policies.

- Enforces Domain Restricted Sharing, Essential Contacts domains, and regional resource locations.
- Blocks Cloud SQL public IPs, VM external IPs, SA keys, and HMAC storage auth.
- Restricts Cloud Run and Cloud Functions ingress to internal and load balancer traffic.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```
