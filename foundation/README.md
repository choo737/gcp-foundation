# Foundation Stages

These stages build the shared organization folder tree, audit logging, and KMS security controls.

## Stage Order

1. `01-org-governance/`: Creates root, shared infrastructure, and workload folders plus the audit project.
2. `02-security-network/`: Creates the netsec project, regional KMS key, and optional VPC or VPC-SC.

## Stage Linking

Run stage 01 first, then link its outputs into stage 02 (`00_linked.auto.tfvars.json`):

```bash
cd foundation/02-security-network
../../scripts/link-stages.sh ../01-org-governance .
terraform init
terraform apply
```
