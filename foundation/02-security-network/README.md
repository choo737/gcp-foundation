# Foundation Stage 02: Security and Network

This stage deploys the central KMS key ring, crypto key, and optional VPC controls.

## Resources Deployed

- `${prefix}-network` project inside `01-shared-infrastructure`.
- Regional Cloud KMS key ring and CMEK key with 90-day rotation.
- Optional custom VPC, Private Service Connect, and dry-run VPC-SC perimeter.

## Usage

```bash
../../scripts/link-stages.sh ../01-org-governance .
terraform init
terraform plan
terraform apply
```
