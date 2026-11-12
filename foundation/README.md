# Foundation Stages

These stages build bootstrap state, organization folders, audit logging, and network security controls.

## Stage Order

1. `00-bootstrap/`: Optional Day-0 `tfstate` and `iac-outputs` buckets plus GitHub Actions WIF on a seed project.
2. `01-org-governance/`: Creates root, shared infrastructure, and workload folders plus the audit project.
3. `02-security-network/`: Creates the netsec project, regional KMS key, and hardened VPC or VPC-SC.

## Stage Linking

Run stage 01 first, then link its outputs into stage 02 (`00_linked.auto.tfvars.json`):

```bash
cd foundation/02-security-network
../../scripts/link-stages.sh ../01-org-governance .
terraform init
terraform apply
```
