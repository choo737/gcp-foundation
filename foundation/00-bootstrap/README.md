# Foundation Stage 00: Bootstrap

This optional Day-0 stage sets up remote state, stage handoff storage, and GitHub OIDC.

## Resources Deployed

- Enables IAM Credentials, STS, IAM, and Cloud Storage APIs on an existing seed project.
- Creates `<prefix>-<suffix>-tfstate` with UBLA, versioning, and enforced public access prevention.
- Creates `<prefix>-<suffix>-iac-outputs` for non-sensitive cross-repo handoff JSON files.
- Creates dedicated CI service accounts (`tf-foundation-ci`, `tf-ingestion-ci`, `dataform-ci`).
- Optionally deploys `module.github_wif` with strict CEL org, repo, ref, and environment rules.

## Usage

```bash
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

Set `enable_github_wif = true` with `github_org` or `github_repositories` for keyless CI/CD.

## Migrating Bootstrap State to GCS

Stage 00 starts with local state because it creates the `tfstate` bucket.
After `terraform apply`, add a `backend "gcs" {}` block and migrate state:

```bash
terraform init -migrate-state \
  -backend-config="bucket=<prefix>-<suffix>-tfstate" \
  -backend-config="prefix=foundation/00-bootstrap/shared"
```
