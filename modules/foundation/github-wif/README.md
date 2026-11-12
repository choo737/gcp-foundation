# GitHub Workload Identity Federation Module

This module creates a keyless GitHub Actions Workload Identity Pool and OIDC provider.

## Resources Managed

- `google_iam_workload_identity_pool` scoped to the bootstrap project.
- `google_iam_workload_identity_pool_provider` trusting `https://token.actions.githubusercontent.com`.
- Mandatory CEL `attribute_condition` restricting tokens to validated `github_org` or `github_repositories`.
- Optional `google_service_account_iam_member` bindings granting `roles/iam.workloadIdentityUser` per repository.

## Usage

```hcl
module "github_wif" {
  source = "../../modules/foundation/github-wif"

  project_id          = var.project_id
  prefix              = var.prefix
  github_org          = "acme-corp"
  github_repositories = ["acme-corp/gcp-foundation"]
}
```
