# Foundation Stage 02: Security and Network

This stage deploys KMS keys, VPC controls, VPC-SC perimeters, and Cloud Monitoring alerts.

## Resources Deployed

- `${prefix}-network` project placed in `02-environments/<env>` or `shared_infra_folder_id`.
- Primary and optional DR Cloud KMS key rings and crypto keys.
- Optional Shared VPC host, subnet with Flow Logs, DNS logging, and Datastream PSC attachment.
- Optional PSC endpoint with `googleapis.com.`, `pkg.dev.`, and `gcr.io.` private DNS zones.
- Optional folder hierarchical firewall policy (`goto_next`) plus threat intelligence deny rules.
- IAM-governed `GCE_FIREWALL` secure tags (`tier` and `access`) wired to VPC firewall rules.
- VPC Global Network Firewall Policy with PSC TCP 443, FQDN egress allowlist, and NGFW Enterprise opt-in.
- Environment-scoped VPC-SC perimeter and five Cloud Monitoring alert policies.

## Usage

```bash
../../scripts/link-stages.sh ../01-org-governance .
terraform init -backend-config="bucket=<tfstate-bucket>" -backend-config="prefix=foundation/02-security-network/dev"
terraform plan -var-file=envs/dev.tfvars.example
```
